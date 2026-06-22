package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.PenaliteTemplateEntity;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PenaliteTemplateJpaRepository extends JpaRepository<PenaliteTemplateEntity, Long> {
}
