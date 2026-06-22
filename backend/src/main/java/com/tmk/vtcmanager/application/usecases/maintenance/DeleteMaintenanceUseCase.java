package com.tmk.vtcmanager.application.usecases.maintenance;

import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.MaintenanceRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class DeleteMaintenanceUseCase {

    private final MaintenanceRepository maintenanceRepository;

    @Transactional
    public void execute(Long id) {
        maintenanceRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Maintenance", id));
        maintenanceRepository.deleteById(id);
    }
}
