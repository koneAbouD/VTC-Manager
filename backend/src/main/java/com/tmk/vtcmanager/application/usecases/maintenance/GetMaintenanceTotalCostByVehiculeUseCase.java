package com.tmk.vtcmanager.application.usecases.maintenance;

import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.ports.persistence.MaintenanceRepository;
import lombok.RequiredArgsConstructor;

import java.math.BigDecimal;

@RequiredArgsConstructor
public class GetMaintenanceTotalCostByVehiculeUseCase {

    private final MaintenanceRepository maintenanceRepository;

    public BigDecimal execute(Long vehiculeId) {
        return maintenanceRepository.findByVehiculeId(vehiculeId).stream()
                .map(Maintenance::getCout)
                .filter(c -> c != null)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }
}
