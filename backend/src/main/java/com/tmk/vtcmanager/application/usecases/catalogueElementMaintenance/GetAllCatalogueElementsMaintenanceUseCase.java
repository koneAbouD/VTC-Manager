package com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance;

import com.tmk.vtcmanager.application.domain.operation.CatalogueElementMaintenance;
import com.tmk.vtcmanager.application.domain.vehicule.Modele;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.CatalogueElementMaintenanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.ModeleRepository;
import lombok.RequiredArgsConstructor;

import java.util.List;

@RequiredArgsConstructor
public class GetAllCatalogueElementsMaintenanceUseCase {

    private final CatalogueElementMaintenanceRepository repository;
    private final ModeleRepository modeleRepository;

    /** Liste complète (actifs ET inactifs) — utilisée par le paramétrage. */
    public List<CatalogueElementMaintenance> execute() {
        return repository.findAll();
    }

    /**
     * Liste complète restreinte à ce que la saisie d'une maintenance proposerait
     * pour un véhicule de ce modèle : éléments génériques, de sa marque, ou de
     * ce modèle (même règle que {@link CatalogueElementMaintenance#estCompatibleAvec}).
     * Le paramétrage s'en sert pour filtrer son catalogue par modèle.
     */
    public List<CatalogueElementMaintenance> execute(Long modeleId) {
        if (modeleId == null) return execute();
        Modele modele = modeleRepository.findById(modeleId)
                .orElseThrow(() -> ResourceNotFoundException.of("Modèle", modeleId));
        Long marqueId = modele.getMarque() != null ? modele.getMarque().getId() : null;
        return repository.findAll().stream()
                .filter(e -> e.estCompatibleAvec(marqueId, modeleId))
                .toList();
    }
}
