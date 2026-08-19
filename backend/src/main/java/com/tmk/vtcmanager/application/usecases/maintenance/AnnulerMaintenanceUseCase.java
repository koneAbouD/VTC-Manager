package com.tmk.vtcmanager.application.usecases.maintenance;

import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.event.VehiculeStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.MaintenanceRepository;
import com.tmk.vtcmanager.application.ports.security.AuteurCourant;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

/**
 * Annulation d'une intervention qui n'aura pas lieu.
 *
 * <p>Elle n'est jamais effacée : l'intervention a figuré au programme du
 * véhicule, et l'historique doit continuer de le montrer. L'annulation
 * l'horodate, la motive et la signe — sans quoi une vidange disparue du
 * planning ne se distingue plus d'un oubli.
 */
@RequiredArgsConstructor
public class AnnulerMaintenanceUseCase {

    private final MaintenanceRepository maintenanceRepository;
    private final VehiculeStatutEventPublisher statutEventPublisher;
    private final AuteurCourant auteurCourant;

    @Transactional
    public Maintenance execute(Long id, String motif) {
        if (motif == null || motif.isBlank()) {
            throw new IllegalArgumentException(
                    "Le motif d'annulation est obligatoire : il justifie le retrait de"
                            + " l'intervention du programme.");
        }

        Maintenance maintenance = maintenanceRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Maintenance", id));

        if (maintenance.getStatut() == MaintenanceStatus.ANNULEE) {
            throw new IllegalStateException("La maintenance est déjà annulée.");
        }
        // Une intervention terminée a produit une dépense — ou une dette envers
        // le prestataire. L'annuler ici la laisserait au journal sans rien en
        // face : une charge orpheline, sans intervention pour la justifier.
        // C'est l'annulation de cette dépense qui défait la complétion, et elle
        // rend la maintenance à l'état planifié.
        if (maintenance.getStatut() == MaintenanceStatus.TERMINEE) {
            throw new IllegalStateException("Cette maintenance est terminée : elle ne s'annule pas"
                    + " ici. Annulez la dépense qu'elle a générée — la maintenance repasse en"
                    + " planifiée — puis annulez-la.");
        }

        maintenance.annuler(motif.trim(), auteurCourant.nom());
        Maintenance saved = maintenanceRepository.save(maintenance);

        // Une maintenance annulée (potentiellement EN_COURS) peut libérer le véhicule.
        if (saved.getVehicule() != null) {
            statutEventPublisher.publishStatutDirty(saved.getVehicule().getId());
        }

        return saved;
    }
}
