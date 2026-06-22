package com.tmk.vtcmanager.application.usecases.maintenance;

import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import com.tmk.vtcmanager.application.ports.persistence.MaintenanceRepository;
import lombok.RequiredArgsConstructor;

import java.time.LocalDate;
import java.util.List;

/**
 * Récupère les maintenances planifiées à venir dans un nombre de jours donné.
 * Utilisé par le scheduler de rappel de maintenance.
 */
@RequiredArgsConstructor
public class GetUpcomingMaintenancesUseCase {

    private final MaintenanceRepository maintenanceRepository;

    public List<Maintenance> execute(int joursAvant) {
        LocalDate seuil = LocalDate.now().plusDays(joursAvant);
        return maintenanceRepository.findByDatePrevueLessThanEqualAndStatut(seuil, MaintenanceStatus.PLANIFIEE);
    }
}
