package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.application.domain.document.CibleDocument;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.DocumentEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface DocumentJpaRepository extends JpaRepository<DocumentEntity, Long> {

    List<DocumentEntity> findByCibleAndCibleIdOrderByCreatedAtDesc(CibleDocument cible, Long cibleId);
}
