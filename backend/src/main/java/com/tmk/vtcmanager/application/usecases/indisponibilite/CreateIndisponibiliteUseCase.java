package com.tmk.vtcmanager.application.usecases.indisponibilite;

import com.tmk.vtcmanager.application.domain.indisponibilite.Indisponibilite;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeTravail;
import com.tmk.vtcmanager.application.exception.ChauffeurNeTravaillePasCeJourException;
import com.tmk.vtcmanager.application.ports.event.ChauffeurStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.ProgrammeTravailRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;

@RequiredArgsConstructor
public class CreateIndisponibiliteUseCase {

    private final IndisponibiliteRepository indisponibiliteRepository;
    private final ProgrammeTravailRepository programmeTravailRepository;
    private final ChauffeurStatutEventPublisher chauffeurStatutEventPublisher;

    @Transactional
    public Indisponibilite execute(Indisponibilite indisponibilite) {
        if (indisponibilite.getChauffeurRemplacant() == null
                || indisponibilite.getChauffeurRemplacant().getId() == null) {
            throw new IllegalArgumentException(
                    "Un chauffeur remplaçant est obligatoire pour une indisponibilité.");
        }
        indisponibilite.validerPourCreation();
        validerJourTravaille(indisponibilite);
        indisponibilite.initializeDefaults();
        // Modèle "overlay" : aucune mutation du programme. Le remplacement est
        // calculé par date à la lecture/génération, uniquement sur la période.
        Indisponibilite saved = indisponibiliteRepository.save(indisponibilite);

        // Le titulaire peut devenir EN_CONGE si la période couvre aujourd'hui.
        if (saved.getChauffeur() != null) {
            chauffeurStatutEventPublisher.publishStatutDirty(saved.getChauffeur().getId());
        }
        // Le remplaçant peut devenir EN_SERVICE (substitution active aujourd'hui).
        if (saved.getChauffeurRemplacant() != null) {
            chauffeurStatutEventPublisher.publishStatutDirty(saved.getChauffeurRemplacant().getId());
        }
        return saved;
    }

    /**
     * Vérifie que le chauffeur travaille effectivement au moins un jour de
     * l'intervalle [début, fin] de l'indisponibilité ; sinon lève une exception.
     * Couvre le cas « un seul jour » (intervalle réduit à ce jour) et le cas
     * « période ».
     */
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
                    return; // travaille au moins un jour → OK
                }
                jour = jour.plusDays(1);
            }
        }
        throw new ChauffeurNeTravaillePasCeJourException();
    }
}
