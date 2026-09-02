package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ReaffectationChauffeurEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ReaffectationChauffeurJpaRepository
        extends JpaRepository<ReaffectationChauffeurEntity, Long> {

    List<ReaffectationChauffeurEntity> findByDocumentTypeAndDocumentIdOrderByIdDesc(
            TypeDocumentCreance documentType, Long documentId);
}
