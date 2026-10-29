package com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance;

import com.tmk.vtcmanager.application.domain.operation.TarifElementMaintenance;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.ModeleRepository;
import com.tmk.vtcmanager.application.ports.persistence.TarifElementMaintenanceRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.util.Set;
import java.util.stream.Collectors;

/**
 * Reprend pour un modèle les éléments d'un autre — un modèle qui entre dans la
 * flotte n'a encore aucun tarif, donc rien à proposer. Les éléments que le
 * modèle cible a déjà ne sont pas touchés.
 */
@RequiredArgsConstructor
public class CopierTarifsElementsMaintenanceUseCase {

    private final TarifElementMaintenanceRepository tarifRepository;
    private final ModeleRepository modeleRepository;

    /** @return le nombre d'éléments ajoutés au modèle cible. */
    @Transactional
    public int execute(Long deModeleId, Long versModeleId, boolean avecPrix, boolean avecImages) {
        if (deModeleId == null || versModeleId == null) {
            throw new IllegalArgumentException("Les deux modèles sont obligatoires.");
        }
        if (deModeleId.equals(versModeleId)) {
            throw new IllegalArgumentException("Choisissez deux modèles différents.");
        }
        modeleRepository.findById(deModeleId)
                .orElseThrow(() -> ResourceNotFoundException.of("Modèle", deModeleId));
        modeleRepository.findById(versModeleId)
                .orElseThrow(() -> ResourceNotFoundException.of("Modèle", versModeleId));

        Set<Long> dejaPresents = tarifRepository.findByModeleId(versModeleId).stream()
                .map(TarifElementMaintenance::getElementId)
                .collect(Collectors.toSet());
        int copies = 0;
        for (TarifElementMaintenance source : tarifRepository.findByModeleId(deModeleId)) {
            if (dejaPresents.contains(source.getElementId())) continue;
            tarifRepository.save(TarifElementMaintenance.builder()
                    .elementId(source.getElementId())
                    .modeleId(versModeleId)
                    .prix(avecPrix ? source.getPrix() : null)
                    .image(avecImages ? source.getImage() : null)
                    .actif(source.isActif())
                    .build());
            copies++;
        }
        return copies;
    }
}
