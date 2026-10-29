package com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance;

import com.tmk.vtcmanager.application.domain.operation.CatalogueElementMaintenance;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.exception.VehiculeNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.CatalogueElementMaintenanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import lombok.RequiredArgsConstructor;

import java.util.List;

/**
 * Éléments de maintenance <b>actifs uniquement</b>, triés par libellé — destinés
 * à la sélection (saisie d'une opération de maintenance). Le paramétrage, lui,
 * consomme la liste complète via {@link GetAllCatalogueElementsMaintenanceUseCase}.
 *
 * <p>Pour un véhicule donné, seuls les éléments compatibles avec sa marque et
 * son modèle sont retenus (voir {@link CatalogueElementMaintenance#estCompatibleAvec}).
 * Pour un type de maintenance donné, seuls les éléments communs ou réservés à
 * ce type le sont (voir {@link CatalogueElementMaintenance#estCompatibleAvecType}).</p>
 */
@RequiredArgsConstructor
public class GetActifsCatalogueElementsMaintenanceUseCase {

    private final CatalogueElementMaintenanceRepository repository;
    private final VehiculeRepository vehiculeRepository;

    public List<CatalogueElementMaintenance> execute() {
        return repository.findAllActifs();
    }

    public List<CatalogueElementMaintenance> execute(Long vehiculeId) {
        return execute(vehiculeId, null);
    }

    public List<CatalogueElementMaintenance> execute(Long vehiculeId, Long categorieTypeId) {
        Vehicule vehicule = vehiculeId == null ? null : vehiculeRepository.findById(vehiculeId)
                .orElseThrow(() -> new VehiculeNotFoundException(vehiculeId));
        return repository.findAllActifs().stream()
                .filter(e -> vehicule == null
                        || e.estCompatibleAvec(vehicule.getMarqueId(), vehicule.getModeleId()))
                .filter(e -> e.estCompatibleAvecType(categorieTypeId))
                .toList();
    }
}
