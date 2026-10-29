package com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance;

import com.tmk.vtcmanager.application.domain.operation.TarifElementMaintenance;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.CatalogueElementMaintenanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.ModeleRepository;
import com.tmk.vtcmanager.application.ports.persistence.TarifElementMaintenanceRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.Objects;

/**
 * Prix, image et activation d'un élément pour un modèle : crée le tarif s'il
 * n'existe pas encore, sinon le met à jour. Une image remplacée n'est effacée
 * du stockage que si aucun autre tarif ne s'en sert.
 */
@RequiredArgsConstructor
public class EnregistrerTarifElementMaintenanceUseCase {

    private final CatalogueElementMaintenanceRepository repository;
    private final TarifElementMaintenanceRepository tarifRepository;
    private final ModeleRepository modeleRepository;
    private final ImagesCatalogueMaintenance images;

    @Transactional
    public TarifElementMaintenance execute(Long elementId, Long modeleId,
                                           BigDecimal prix, String image, boolean actif) {
        repository.findById(elementId)
                .orElseThrow(() -> ResourceNotFoundException.of("Élément catalogue", elementId));
        if (modeleId == null) {
            throw new IllegalArgumentException("Le modèle de véhicule est obligatoire.");
        }
        modeleRepository.findById(modeleId)
                .orElseThrow(() -> ResourceNotFoundException.of("Modèle", modeleId));

        TarifElementMaintenance tarif = tarifRepository.findByElementIdAndModeleId(elementId, modeleId)
                .orElseGet(() -> TarifElementMaintenance.builder()
                        .elementId(elementId)
                        .modeleId(modeleId)
                        .build());
        String ancienneImage = tarif.getImage();
        tarif.modifier(prix, image, actif);
        TarifElementMaintenance enregistre = tarifRepository.save(tarif);
        if (!Objects.equals(ancienneImage, image)) images.supprimerSiOrpheline(ancienneImage);
        return enregistre;
    }
}
