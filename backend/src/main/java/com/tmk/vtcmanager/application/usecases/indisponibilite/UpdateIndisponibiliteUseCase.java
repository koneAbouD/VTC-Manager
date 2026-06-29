package com.tmk.vtcmanager.application.usecases.indisponibilite;

import com.tmk.vtcmanager.application.domain.indisponibilite.Indisponibilite;
import com.tmk.vtcmanager.application.domain.indisponibilite.IndisponibiliteStatut;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeTravail;
import com.tmk.vtcmanager.application.exception.ChauffeurNeTravaillePasCeJourException;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.event.ChauffeurStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.ProgrammeTravailRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;

@RequiredArgsConstructor
public class UpdateIndisponibiliteUseCase {

    private final IndisponibiliteRepository indisponibiliteRepository;
    private final ProgrammeTravailRepository programmeTravailRepository;
    private final ChauffeurStatutEventPublisher chauffeurStatutEventPublisher;

    @Transactional
    public Indisponibilite execute(Long id, Indisponibilite data) {
        Indisponibilite existing = indisponibiliteRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Indisponibilité", id));
        // Titulaire d'origine (peut changer) : il faudra recalculer son statut aussi.
        final Long ancienTitulaireId = existing.getChauffeur() != null
                ? existing.getChauffeur().getId() : null;
        if (existing.getStatut() == IndisponibiliteStatut.TERMINEE
                || existing.getStatut() == IndisponibiliteStatut.ANNULEE) {
            throw new IllegalArgumentException(
                    "Une indisponibilité terminée ou annulée ne peut pas être modifiée.");
        }
        if (data.getChauffeurRemplacant() == null
                || data.getChauffeurRemplacant().getId() == null) {
            throw new IllegalArgumentException(
                    "Un chauffeur remplaçant est obligatoire pour une indisponibilité.");
        }
        data.validerCoherence();

        // ── Protection des jours passés ────────────────────────────────────
        // On ne doit jamais réécrire la partie déjà écoulée d'une indisponibilité.
        final LocalDate today = LocalDate.now();
        final boolean dejaDemarree = existing.getDateDebut() != null
                && !existing.getDateDebut().isAfter(today);
        if (dejaDemarree) {
            // En cours : la date de début reste celle d'origine (jours passés
            // intouchés) et la date de fin ne peut pas repasser avant aujourd'hui.
            data.setDateDebut(existing.getDateDebut());
            if (data.getDateFin() != null && data.getDateFin().isBefore(today)) {
                throw new IllegalArgumentException(
                        "La date de fin ne peut pas être antérieure à aujourd'hui "
                                + "pour une indisponibilité en cours.");
            }
        } else if (data.getDateDebut() != null && data.getDateDebut().isBefore(today)) {
            // Planifiée : interdiction de la déplacer sur une date passée.
            throw new IllegalArgumentException(
                    "L'indisponibilité ne peut pas être déplacée sur une date passée.");
        }
        data.validerCoherence();

        validerJourTravaille(data);

        existing.setChauffeur(data.getChauffeur());
        existing.setChauffeurRemplacant(data.getChauffeurRemplacant());
        existing.setDateDebut(data.getDateDebut());
        existing.setDateFin(data.getDateFin());
        existing.setMotif(data.getMotif());
        existing.setCommentaire(data.getCommentaire());
        existing.setStatut(data.getStatut() != null
                ? data.getStatut()
                : existing.computeStatutFromDates());

        // Modèle "overlay" : aucune mutation du programme (substitution calculée
        // par date). Le programme normal est donc rétabli automatiquement hors
        // période / à la fin de l'indisponibilité.
        Indisponibilite saved = indisponibiliteRepository.save(existing);

        // Recalcul du statut pour l'ancien et le nouveau titulaire (la période ou
        // le titulaire ont pu changer).
        chauffeurStatutEventPublisher.publishStatutDirty(ancienTitulaireId);
        Long nouveauTitulaireId = saved.getChauffeur() != null ? saved.getChauffeur().getId() : null;
        if (nouveauTitulaireId != null && !nouveauTitulaireId.equals(ancienTitulaireId)) {
            chauffeurStatutEventPublisher.publishStatutDirty(nouveauTitulaireId);
        }
        return saved;
    }

    private void validerJourTravaille(Indisponibilite indispo) {
        final LocalDate debut = indispo.getDateDebut();
        if (debut == null) return;
        final LocalDate fin = indispo.getDateFin() != null ? indispo.getDateFin() : debut;

        final Long titulaireId =
                indispo.getChauffeur() != null ? indispo.getChauffeur().getId() : null;
        if (titulaireId == null) return;

        ProgrammeTravail programme =
                programmeTravailRepository.findByChauffeurId(titulaireId).orElse(null);
        if (programme != null) {
            LocalDate jour = debut;
            int garde = 0;
            while (!jour.isAfter(fin) && garde++ < 1000) {
                if (programme.travailleCeJour(jour)
                        && programme.chauffeursActifs(jour).contains(titulaireId)) {
                    return;
                }
                jour = jour.plusDays(1);
            }
        }
        throw new ChauffeurNeTravaillePasCeJourException();
    }
}
