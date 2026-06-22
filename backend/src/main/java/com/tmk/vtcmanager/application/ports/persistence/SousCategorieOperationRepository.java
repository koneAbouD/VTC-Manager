package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.operation.SousCategorieOperation;

import java.util.List;
import java.util.Optional;

public interface SousCategorieOperationRepository {

    SousCategorieOperation save(SousCategorieOperation sousCategorie);

    Optional<SousCategorieOperation> findById(Long id);

    List<SousCategorieOperation> findAll();

    Optional<SousCategorieOperation> findByCategorieId(Long categorieId);

    Optional<SousCategorieOperation> findByCode(String code);

    boolean existsByCode(String code);

    void deleteById(Long id);
}
