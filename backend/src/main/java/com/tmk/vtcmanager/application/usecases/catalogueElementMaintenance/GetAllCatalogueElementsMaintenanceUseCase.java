package com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance;

import com.tmk.vtcmanager.application.domain.operation.ElementCatalogue;
import com.tmk.vtcmanager.application.domain.operation.TarifElementMaintenance;
import com.tmk.vtcmanager.application.ports.persistence.CatalogueElementMaintenanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.TarifElementMaintenanceRepository;
import lombok.RequiredArgsConstructor;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RequiredArgsConstructor
public class GetAllCatalogueElementsMaintenanceUseCase {

    private final CatalogueElementMaintenanceRepository repository;
    private final TarifElementMaintenanceRepository tarifRepository;

    /** Catalogue complet (actifs ET inactifs) avec les tarifs de chaque modèle — paramétrage. */
    public List<ElementCatalogue> execute() {
        Map<Long, List<TarifElementMaintenance>> parElement = tarifRepository.findAll().stream()
                .collect(Collectors.groupingBy(TarifElementMaintenance::getElementId));
        return repository.findAll().stream()
                .map(e -> new ElementCatalogue(e, parElement.getOrDefault(e.getId(), List.of())))
                .toList();
    }

    /**
     * Éléments qui ont un tarif pour ce modèle, actifs ou non — l'onglet du
     * modèle dans le paramétrage.
     */
    public List<ElementCatalogue> execute(Long modeleId) {
        if (modeleId == null) return execute();
        return execute().stream()
                .filter(ec -> ec.tarifPour(modeleId).isPresent())
                .toList();
    }
}
