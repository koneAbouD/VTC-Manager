package com.tmk.vtcmanager.application.usecases.maintenance;

import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.event.VehiculeStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.MaintenanceRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class AnnulerMaintenanceUseCase {

    private final MaintenanceRepository maintenanceRepository;
    private final VehiculeStatutEventPublisher statutEventPublisher;

    @Transactional
    public Maintenance execute(Long id) {
        Maintenance maintenance = maintenanceRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Maintenance", id));

        if (maintenance.getStatut() == MaintenanceStatus.ANNULEE) {
            throw new IllegalStateException("La maintenance est déjà annulée.");
        }

        maintenance.annuler();
        Maintenance saved = maintenanceRepository.save(maintenance);

        // Une maintenance annulée (potentiellement EN_COURS) peut libérer le véhicule.
        if (saved.getVehicule() != null) {
            statutEventPublisher.publishStatutDirty(saved.getVehicule().getId());
        }

        return saved;
    }
}
