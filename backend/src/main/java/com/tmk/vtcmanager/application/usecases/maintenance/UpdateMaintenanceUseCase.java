package com.tmk.vtcmanager.application.usecases.maintenance;

import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.event.VehiculeStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import com.tmk.vtcmanager.application.ports.persistence.MaintenanceRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@RequiredArgsConstructor
public class UpdateMaintenanceUseCase {

    private final MaintenanceRepository maintenanceRepository;
    private final CategorieOperationRepository categorieOperationRepository;
    private final VehiculeStatutEventPublisher statutEventPublisher;

    @Transactional
    public Maintenance execute(Long id, Maintenance data) {
        validerType(data.getType());

        Maintenance existing = maintenanceRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Maintenance", id));
        existing.setType(data.getType());
        existing.setDatePrevue(data.getDatePrevue());
        existing.setDateEffectuee(data.getDateEffectuee());
        existing.setDescription(data.getDescription());
        existing.setKilometrageAuMoment(data.getKilometrageAuMoment());
        existing.setKilometrageProchaine(data.getKilometrageProchaine());
        existing.setCout(data.getCout());
        existing.setPrestataire(data.getPrestataire());
        if (data.getStatut() != null) existing.setStatut(data.getStatut());
        Maintenance saved = maintenanceRepository.save(existing);

        // Le statut de la maintenance a pu changer (EN_COURS / TERMINEE / ANNULEE)
        // → recalcul du statut du véhicule.
        if (existing.getVehicule() != null) {
            statutEventPublisher.publishStatutDirty(existing.getVehicule().getId());
        }
        return saved;
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
