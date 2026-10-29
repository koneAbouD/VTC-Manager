package com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance;

import com.tmk.vtcmanager.application.domain.operation.ElementCatalogue;
import com.tmk.vtcmanager.application.domain.operation.PropositionCatalogue;
import com.tmk.vtcmanager.application.domain.operation.TarifElementMaintenance;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.exception.VehiculeNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.CatalogueElementMaintenanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.TarifElementMaintenanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import lombok.RequiredArgsConstructor;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * Éléments de maintenance <b>proposés à la saisie</b>, triés par libellé. Le
 * paramétrage, lui, consomme le catalogue complet via
 * {@link GetAllCatalogueElementsMaintenanceUseCase}.
 *
 * <p>Pour un véhicule, seuls les éléments qui ont un tarif actif pour son modèle
 * sont proposés, avec le prix et l'image de ce modèle (voir
 * {@link ElementCatalogue#estProposePour}). Pour un type de maintenance, seuls
 * les éléments communs ou réservés à ce type le sont.</p>
 */
@RequiredArgsConstructor
public class GetActifsCatalogueElementsMaintenanceUseCase {

    private final CatalogueElementMaintenanceRepository repository;
    private final TarifElementMaintenanceRepository tarifRepository;
    private final VehiculeRepository vehiculeRepository;

    /**
     * @param vehiculeId véhicule de l'intervention ; sans véhicule, tous les
     *                   éléments actifs, sans prix ni image (aucun modèle ne les
     *                   désigne).
     */
    public PropositionCatalogue execute(Long vehiculeId, Long categorieTypeId) {
        if (vehiculeId == null) {
            return new PropositionCatalogue(null, repository.findAllActifs().stream()
                    .filter(e -> e.estCompatibleAvecType(categorieTypeId))
                    .map(e -> new ElementCatalogue(e, List.of()))
                    .toList());
        }
        Vehicule vehicule = vehiculeRepository.findById(vehiculeId)
                .orElseThrow(() -> new VehiculeNotFoundException(vehiculeId));
        Long modeleId = vehicule.getModeleId();
        // Un véhicule sans modèle n'a pas de tarifs : rien à proposer, les
        // éléments se saisissent alors librement.
        if (modeleId == null) return new PropositionCatalogue(null, List.of());

        Map<Long, List<TarifElementMaintenance>> parElement = tarifRepository.findByModeleId(modeleId)
                .stream()
                .collect(Collectors.groupingBy(TarifElementMaintenance::getElementId));
        return new PropositionCatalogue(modeleId, repository.findAllActifs().stream()
                .map(e -> new ElementCatalogue(e, parElement.getOrDefault(e.getId(), List.of())))
                .filter(ec -> ec.estProposePour(modeleId))
                .filter(ec -> ec.element().estCompatibleAvecType(categorieTypeId))
                .toList());
    }
}
