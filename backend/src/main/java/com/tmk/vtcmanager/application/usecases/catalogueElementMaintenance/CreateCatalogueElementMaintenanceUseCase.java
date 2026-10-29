package com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance;

import com.tmk.vtcmanager.application.domain.operation.CatalogueElementMaintenance;
import com.tmk.vtcmanager.application.domain.operation.ElementCatalogue;
import com.tmk.vtcmanager.application.domain.operation.TarifElementMaintenance;
import com.tmk.vtcmanager.application.ports.persistence.CatalogueElementMaintenanceRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;

/**
 * Crée un élément du catalogue, et son tarif pour un modèle quand il est
 * désigné (création depuis l'onglet d'un modèle). L'unicité du libellé est
 * garantie par l'index {@code uk_catalogue_elements_maintenance_libelle_ci}
 * (→ 409 via le gestionnaire d'exceptions global).
 */
@RequiredArgsConstructor
public class CreateCatalogueElementMaintenanceUseCase {

    private final CatalogueElementMaintenanceRepository repository;
    private final TypeMaintenanceCatalogue typeMaintenance;
    private final EnregistrerTarifElementMaintenanceUseCase enregistrerTarif;

    @Transactional
    public ElementCatalogue execute(CatalogueElementMaintenance element,
                                    Long modeleId, BigDecimal prix, String image) {
        element.setActif(true);
        typeMaintenance.appliquer(element, element.getCategorieTypeId());
        CatalogueElementMaintenance cree = repository.save(element);
        if (modeleId == null) return new ElementCatalogue(cree, List.of());
        TarifElementMaintenance tarif = enregistrerTarif.execute(cree.getId(), modeleId, prix, image, true);
        return new ElementCatalogue(cree, List.of(tarif));
    }
}
