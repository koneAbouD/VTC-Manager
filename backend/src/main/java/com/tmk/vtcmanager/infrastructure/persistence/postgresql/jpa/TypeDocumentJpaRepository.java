package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.application.domain.document.CibleDocument;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.TypeDocumentEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface TypeDocumentJpaRepository extends JpaRepository<TypeDocumentEntity, Long> {

    @Query("SELECT t FROM TypeDocumentEntity t WHERE t.cible = :cible")
    List<TypeDocumentEntity> findByCibleOrLesDeux(CibleDocument cible);

    Optional<TypeDocumentEntity> findByNom(String nom);
}