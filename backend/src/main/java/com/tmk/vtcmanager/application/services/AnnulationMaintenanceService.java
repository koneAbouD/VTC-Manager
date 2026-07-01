package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.ports.event.VehiculeStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.MaintenanceRepository;
import lombok.RequiredArgsConstructor;

/**
 * Lorsqu'une opération de dépense issue d'une complétion de maintenance est
 * annulée, la maintenance sous-jacente doit revenir à son état antérieur : on
 * la rouvre (EN_COURS, date d'exécution et coût effacés) et on recalcule le
 * statut du véhicule (retour EN_MAINTENANCE le cas échéant).
 * <p>
 * No-op pour les opérations non liées à une maintenance.
 */
@RequiredArgsConstructor
public class AnnulationMaintenanceService {

    private final MaintenanceRepository maintenanceRepository;
    private final VehiculeStatutEventPublisher statutEventPublisher;

    public void reouvrirMaintenanceLiee(OperationFinanciere operation) {
        if (operation == null || operation.getMaintenanceId() == null) {
            return;
        }
        Maintenance maintenance = maintenanceRepository.findById(operation.getMaintenanceId()).orElse(null);
        // On ne rouvre que si elle est encore TERMINEE (idempotent).
        if (maintenance == null || maintenance.getStatut() != MaintenanceStatus.TERMINEE) {
            return;
        }
        maintenance.reouvrir();
        Maintenance saved = maintenanceRepository.save(maintenance);

        if (saved.getVehicule() != null) {
            statutEventPublisher.publishStatutDirty(saved.getVehicule().getId());
        }
    }
}
