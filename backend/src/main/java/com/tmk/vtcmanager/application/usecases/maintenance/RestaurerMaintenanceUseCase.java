package com.tmk.vtcmanager.application.usecases.maintenance;

import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.event.VehiculeStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.MaintenanceRepository;
import com.tmk.vtcmanager.application.services.VerrouArreteService;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

/**
 * Remet en circulation une maintenance annulée à tort : elle repasse en
 * planifiée, l'intervention est de nouveau à faire.
 *
 * <p>Le statut du véhicule est recalculé — une intervention de nouveau au
 * programme peut le rendre indisponible.
 *
 * <p>Refusé une fois la période de l'intervention clôturée : le mois a été
 * arrêté sans elle.
 */
@RequiredArgsConstructor
public class RestaurerMaintenanceUseCase {

    private final MaintenanceRepository maintenanceRepository;
    private final VehiculeStatutEventPublisher statutEventPublisher;
    private final VerrouArreteService verrouArreteService;

    @Transactional
    public Maintenance execute(Long id) {
        Maintenance maintenance = maintenanceRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Maintenance", id));

        if (maintenance.getStatut() != MaintenanceStatus.ANNULEE) {
            throw new IllegalStateException(
                    "Cette maintenance n'est pas annulée : rien à restaurer.");
        }
        verrouArreteService.verifier(maintenance.getDatePrevue());

        maintenance.restaurer();
        Maintenance saved = maintenanceRepository.save(maintenance);

        if (saved.getVehicule() != null) {
            statutEventPublisher.publishStatutDirty(saved.getVehicule().getId());
        }
        return saved;
    }
}
