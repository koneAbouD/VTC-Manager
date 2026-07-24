package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ParametreGeneralEntity;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ParametreGeneralJpaRepository
        extends JpaRepository<ParametreGeneralEntity, String> {
}
