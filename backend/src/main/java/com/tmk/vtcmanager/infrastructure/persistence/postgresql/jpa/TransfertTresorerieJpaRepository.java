package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.TransfertTresorerieEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface TransfertTresorerieJpaRepository extends JpaRepository<TransfertTresorerieEntity, Long> {

    List<TransfertTresorerieEntity> findAllByOrderByDateTransfertDescIdDesc();
}
