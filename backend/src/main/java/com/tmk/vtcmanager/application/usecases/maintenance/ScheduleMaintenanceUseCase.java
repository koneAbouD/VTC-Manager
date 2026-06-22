package com.tmk.vtcmanager.application.usecases.maintenance;

import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.exception.VehiculeNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import com.tmk.vtcmanager.application.ports.persistence.MaintenanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * Planification (création) d'une maintenance pour un véhicule.
 * Valide que le type fourni correspond à une catégorie de la sous-catégorie "Maintenances".
 * Met également à jour la date de prochaine maintenance du véhicule si plus proche.
 */
@RequiredArgsConstructor
public class ScheduleMaintenanceUseCase {

    private final MaintenanceRepository maintenanceRepository;
    private final VehiculeRepository vehiculeRepository;
    private final CategorieOperationRepository categorieOperationRepository;

    @Transactional
    public Maintenance execute(Long vehiculeId, Maintenance maintenance) {
        validerType(maintenance.getType());

        if (vehiculeId != null) {
            Vehicule vehicule = vehiculeRepository.findById(vehiculeId)
                    .orElseThrow(() -> new VehiculeNotFoundException(vehiculeId));
            maintenance.setVehicule(vehicule);

            if (maintenance.getDatePrevue() != null) {
                vehicule.updateProchaineMaintenance(maintenance.getDatePrevue());
                vehiculeRepository.save(vehicule);
            }
        }

        maintenance.initializeDefaults();
        return maintenanceRepository.save(maintenance);
    }

    private void validerType(String type) {
        if (type == null || type.isBlank()) return;
        List<CategorieOperation> typesValides =
                categorieOperationRepository.findBySousCategorieLibelle("Maintenances");
        boolean valide = typesValides.stream()
                .anyMatch(c -> c.getCode().equals(type));
        if (!valide) {
            List<String> codes = typesValides.stream()
                    .map(CategorieOperation::getCode)
                    .toList();
            throw new IllegalArgumentException(
                    "Type de maintenance invalide : '" + type + "'. Types disponibles : " + codes);
        }
    }
}
