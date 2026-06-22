package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.SousCategorieOperationEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface SousCategorieOperationJpaRepository extends JpaRepository<SousCategorieOperationEntity, Long> {

    Optional<SousCategorieOperationEntity> findByCategorieId(Long categorieId);

    Optional<SousCategorieOperationEntity> findByCode(String code);

    boolean existsByCode(String code);
}
