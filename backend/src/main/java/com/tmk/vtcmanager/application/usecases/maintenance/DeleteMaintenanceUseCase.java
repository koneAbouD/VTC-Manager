package com.tmk.vtcmanager.application.usecases.maintenance;

import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.event.VehiculeStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.MaintenanceRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class DeleteMaintenanceUseCase {

    private final MaintenanceRepository maintenanceRepository;
    private final VehiculeStatutEventPublisher statutEventPublisher;

    @Transactional
    public void execute(Long id) {
        Maintenance maintenance = maintenanceRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Maintenance", id));
        Long vehiculeId = maintenance.getVehicule() != null ? maintenance.getVehicule().getId() : null;

        maintenanceRepository.deleteById(id);

        // La suppression d'une maintenance (potentiellement EN_COURS) peut libérer le véhicule.
        statutEventPublisher.publishStatutDirty(vehiculeId);
    }
}
