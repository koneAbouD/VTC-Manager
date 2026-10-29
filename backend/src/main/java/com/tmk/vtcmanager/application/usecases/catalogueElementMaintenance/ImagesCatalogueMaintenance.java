package com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance;

import com.tmk.vtcmanager.application.ports.persistence.TarifElementMaintenanceRepository;
import com.tmk.vtcmanager.application.ports.storage.FileStoragePort;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Nettoyage des images du catalogue de maintenance. Une même image peut servir
 * à plusieurs modèles — reprise à la migration, ou photo réutilisée : le fichier
 * n'est effacé que lorsque plus aucun tarif ne s'en sert.
 */
@Slf4j
@RequiredArgsConstructor
public class ImagesCatalogueMaintenance {

    private final TarifElementMaintenanceRepository tarifRepository;
    private final FileStoragePort storage;

    /** À appeler une fois le tarif modifié ou supprimé. Échec sans conséquence. */
    public void supprimerSiOrpheline(String image) {
        if (image == null || image.isBlank()) return;
        if (tarifRepository.compterParImage(image) > 0) return;
        try {
            storage.delete(image);
        } catch (Exception e) {
            log.warn("Suppression de l'image '{}' échouée : {}", image, e.getMessage());
        }
    }
}
