package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;

import java.util.List;
import java.util.Optional;

public interface CategorieOperationRepository {

    CategorieOperation save(CategorieOperation categorie);

    Optional<CategorieOperation> findById(Long id);

    List<CategorieOperation> findAll();

    List<CategorieOperation> findByTypeOperation(TypeOperation typeOperation);

    List<CategorieOperation> findBySousCategorieCode(String sousCategorieCode);

    List<CategorieOperation> findBySousCategorieLibelle(String libelle);

    Optional<CategorieOperation> findByCode(String code);

    boolean existsByCode(String code);

    void deleteById(Long id);
}
