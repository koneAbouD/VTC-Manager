package com.tmk.vtcmanager.application.usecases.sousCategorieOperation;

import com.tmk.vtcmanager.application.domain.operation.SousCategorieOperation;
import com.tmk.vtcmanager.application.exception.ResourceAlreadyExistsException;
import com.tmk.vtcmanager.application.ports.persistence.SousCategorieOperationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class CreateSousCategorieOperationUseCase {

    private final SousCategorieOperationRepository sousCategorieRepository;

    @Transactional
    public SousCategorieOperation execute(SousCategorieOperation sousCategorie) {
        if (sousCategorieRepository.existsByCode(sousCategorie.getCode())) {
            throw new ResourceAlreadyExistsException("Une sous-catégorie avec le code '" + sousCategorie.getCode() + "' existe déjà.");
        }
        sousCategorie.setActif(true);
        return sousCategorieRepository.save(sousCategorie);
    }
}
