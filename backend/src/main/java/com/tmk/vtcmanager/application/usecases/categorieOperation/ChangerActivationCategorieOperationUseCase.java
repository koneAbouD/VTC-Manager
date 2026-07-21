package com.tmk.vtcmanager.application.usecases.categorieOperation;

import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

/**
 * Active / désactive (soft-disable) une catégorie d'opération, sans la
 * supprimer — préserve les opérations existantes qui la référencent.
 */
@RequiredArgsConstructor
public class ChangerActivationCategorieOperationUseCase {

    private final CategorieOperationRepository categorieRepository;

    @Transactional
    public CategorieOperation execute(Long id, boolean actif) {
        CategorieOperation existant = categorieRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Catégorie d'opération", id));
        existant.setActif(actif);
        return categorieRepository.save(existant);
    }
}
