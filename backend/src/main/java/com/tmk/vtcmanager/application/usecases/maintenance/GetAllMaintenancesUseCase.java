package com.tmk.vtcmanager.application.usecases.maintenance;

import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import com.tmk.vtcmanager.application.ports.persistence.MaintenanceRepository;
import lombok.RequiredArgsConstructor;

import java.time.LocalDate;
import java.util.List;

@RequiredArgsConstructor
public class GetAllMaintenancesUseCase {

    private final MaintenanceRepository maintenanceRepository;

    public List<Maintenance> execute(Long vehiculeId, LocalDate dateDebut, LocalDate dateFin, MaintenanceStatus statut) {
        if (dateDebut != null || dateFin != null || statut != null) {
            return maintenanceRepository.findByFiltres(dateDebut, dateFin, statut, vehiculeId);
        }
        return vehiculeId == null
                ? maintenanceRepository.findAll()
                : maintenanceRepository.findByVehiculeId(vehiculeId);
    }
}
