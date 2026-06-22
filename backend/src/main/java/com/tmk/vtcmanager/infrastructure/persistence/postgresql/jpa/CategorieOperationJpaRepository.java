package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.CategorieOperationEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface CategorieOperationJpaRepository extends JpaRepository<CategorieOperationEntity, Long> {

    List<CategorieOperationEntity> findByTypeOperation(TypeOperation typeOperation);

    Optional<CategorieOperationEntity> findByCode(String code);

    boolean existsByCode(String code);

    @Query("SELECT c FROM CategorieOperationEntity c WHERE c.sousCategorie.code = :sousCategorieCode AND c.actif = true ORDER BY c.libelle ASC")
    List<CategorieOperationEntity> findBySousCategorieCode(@Param("sousCategorieCode") String sousCategorieCode);

    @Query("SELECT c FROM CategorieOperationEntity c WHERE LOWER(c.sousCategorie.libelle) LIKE LOWER(CONCAT('%', :libelle, '%')) AND c.actif = true ORDER BY c.libelle ASC")
    List<CategorieOperationEntity> findBySousCategorieLibelle(@Param("libelle") String libelle);
}
