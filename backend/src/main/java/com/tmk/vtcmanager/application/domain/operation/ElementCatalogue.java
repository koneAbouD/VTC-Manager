package com.tmk.vtcmanager.application.domain.operation;

import java.util.List;
import java.util.Optional;

/**
 * Un élément du catalogue avec ses tarifs, un par modèle de véhicule.
 */
public record ElementCatalogue(CatalogueElementMaintenance element,
                               List<TarifElementMaintenance> tarifs) {

    public ElementCatalogue {
        tarifs = tarifs == null ? List.of() : List.copyOf(tarifs);
    }

    public Optional<TarifElementMaintenance> tarifPour(Long modeleId) {
        if (modeleId == null) return Optional.empty();
        return tarifs.stream().filter(t -> modeleId.equals(t.getModeleId())).findFirst();
    }

    /**
     * Vrai si la saisie d'une maintenance doit proposer l'élément pour ce
     * modèle : l'élément est actif et son tarif pour ce modèle aussi.
     */
    public boolean estProposePour(Long modeleId) {
        return element.isActif()
                && tarifPour(modeleId).map(TarifElementMaintenance::isActif).orElse(false);
    }
}
