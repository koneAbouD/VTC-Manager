package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.IndisponibiliteRemplacementEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface IndisponibiliteRemplacementJpaRepository
        extends JpaRepository<IndisponibiliteRemplacementEntity, Long> {

    List<IndisponibiliteRemplacementEntity> findByIndisponibiliteId(Long indisponibiliteId);

    void deleteByIndisponibiliteId(Long indisponibiliteId);
}
