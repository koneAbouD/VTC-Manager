package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.indisponibilite.Indisponibilite;
import com.tmk.vtcmanager.application.domain.indisponibilite.IndisponibiliteStatut;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeChauffeur;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeTravail;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.ProgrammeTravailRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import java.time.LocalDate;

/// Nettoie les indisponibilités devenues sans effet après une reconfiguration
/// véhicule ou une modification de condition de travail.
///
/// Deux cas :
///  - le chauffeur ne conduit plus aucun véhicule (orphelin) ;
///  - avec le nouveau planning, le titulaire ne travaille plus aucun jour
///    (à venir) de sa période d'indisponibilité.
///
/// Dans les deux cas : indispo en cours → clôturée (jours passés conservés),
/// indispo planifiée → annulée. Chaque action est journalisée et tracée dans
/// le commentaire de l'indisponibilité (historisation légère).
@Slf4j
@RequiredArgsConstructor
public class IndisponibiliteNettoyageService {

    private final IndisponibiliteRepository indisponibiliteRepository;
    private final ProgrammeTravailRepository programmeTravailRepository;

    /**
     * Si [chauffeurId] n'est rattaché à aucun programme (ne conduit plus rien),
     * clôture/annule ses indisponibilités encore actives.
     */
    public void nettoyerSiOrphelin(Long chauffeurId) {
        if (chauffeurId == null) return;
        if (programmeTravailRepository.findByChauffeurId(chauffeurId).isPresent()) {
            return; // encore rattaché → l'indispo reste pertinente
        }
        for (Indisponibilite indispo : indisponibiliteRepository.findByChauffeurId(chauffeurId)) {
            cloturerOuAnnuler(indispo, "chauffeur retiré de tout programme");
        }
    }

    /**
     * Pour les chauffeurs du programme, clôture/annule les indisponibilités dont
     * le titulaire ne travaille plus aucun jour (à venir) avec ce planning.
     */
    public void nettoyerInertes(ProgrammeTravail programme) {
        if (programme == null || programme.getChauffeurs() == null) return;
        for (ProgrammeChauffeur pc : programme.getChauffeurs()) {
            final Long titulaireId = pc.getChauffeurId();
            if (titulaireId == null) continue;
            for (Indisponibilite indispo : indisponibiliteRepository.findByChauffeurId(titulaireId)) {
                if (indispo.getStatut() != IndisponibiliteStatut.EN_COURS
                        && indispo.getStatut() != IndisponibiliteStatut.PLANIFIEE) {
                    continue;
                }
                if (!travailleAuMoinsUnJour(programme, titulaireId, indispo)) {
                    cloturerOuAnnuler(indispo, "le titulaire ne travaille plus aucun jour de la période");
                }
            }
        }
    }

    // ── Helpers ─────────────────────────────────────────────────────────────

    private void cloturerOuAnnuler(Indisponibilite indispo, String raison) {
        final String trace;
        if (indispo.getStatut() == IndisponibiliteStatut.EN_COURS) {
            indispo.terminer();
            trace = "Clôturée automatiquement";
        } else if (indispo.getStatut() == IndisponibiliteStatut.PLANIFIEE) {
            indispo.annuler();
            trace = "Annulée automatiquement";
        } else {
            return;
        }
        ajouterTrace(indispo, trace + " (" + raison + ") le " + LocalDate.now());
        indisponibiliteRepository.save(indispo);
        log.info("Indisponibilité {} (chauffeur {}) -> {} : {}",
                indispo.getId(),
                indispo.getChauffeur() != null ? indispo.getChauffeur().getId() : null,
                indispo.getStatut(), raison);
    }

    private void ajouterTrace(Indisponibilite indispo, String note) {
        final String actuel = indispo.getCommentaire();
        indispo.setCommentaire(actuel == null || actuel.isBlank() ? note : actuel + "\n" + note);
    }

    /** Le titulaire travaille-t-il au moins un jour (à venir) de la période ? */
    private boolean travailleAuMoinsUnJour(
            ProgrammeTravail programme, Long titulaireId, Indisponibilite indispo) {
        if (indispo.getDateDebut() == null) return true;
        final LocalDate today = LocalDate.now();
        // On ne juge que la partie restante (à venir) : le passé est déjà consommé.
        LocalDate jour = indispo.getDateDebut().isBefore(today) ? today : indispo.getDateDebut();
        final LocalDate fin = indispo.getDateFin() != null ? indispo.getDateFin() : jour;
        int garde = 0;
        while (!jour.isAfter(fin) && garde++ < 1000) {
            if (programme.travailleCeJour(jour)
                    && programme.chauffeursActifs(jour).contains(titulaireId)) {
                return true;
            }
            jour = jour.plusDays(1);
        }
        return false;
    }
}
