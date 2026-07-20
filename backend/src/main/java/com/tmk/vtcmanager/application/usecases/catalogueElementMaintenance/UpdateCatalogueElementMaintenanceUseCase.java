package com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance;

import com.tmk.vtcmanager.application.domain.operation.CatalogueElementMaintenance;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.CatalogueElementMaintenanceRepository;
import com.tmk.vtcmanager.application.ports.storage.FileStoragePort;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.Objects;

/**
 * Met à jour le libellé d'un élément de catalogue de maintenance. L'unicité du
 * libellé est garantie par la contrainte {@code uk_catalogue_elements_maintenance_libelle}
 * (→ 409 via le gestionnaire d'exceptions global).
 */
@Slf4j
@RequiredArgsConstructor
public class UpdateCatalogueElementMaintenanceUseCase {

    private final CatalogueElementMaintenanceRepository repository;
    private final FileStoragePort storage;

    @Transactional
    public CatalogueElementMaintenance execute(Long id, String libelle,
                                               BigDecimal montantDefaut, String image) {
        CatalogueElementMaintenance element = repository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Élément catalogue", id));
        String ancienneImage = element.getImage();
        element.update(libelle, montantDefaut, image);
        CatalogueElementMaintenance saved = repository.save(element);

        // Nettoyage best-effort : supprime l'ancien fichier si l'image a changé
        // ou été retirée (évite les orphelins dans le stockage). Un échec de
        // suppression ne doit pas faire échouer la mise à jour.
        if (ancienneImage != null && !ancienneImage.isBlank()
                && !Objects.equals(ancienneImage, image)) {
            try {
                storage.delete(ancienneImage);
            } catch (Exception e) {
                log.warn("Suppression de l'ancienne image '{}' échouée : {}", ancienneImage, e.getMessage());
            }
        }
        return saved;
    }
}
