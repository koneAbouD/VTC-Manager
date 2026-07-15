package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.PaiementEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface PaiementJpaRepository extends JpaRepository<PaiementEntity, Long> {

    Optional<PaiementEntity> findByReference(String reference);

    Optional<PaiementEntity> findByGatewayReference(String gatewayReference);

    List<PaiementEntity> findByChauffeurIdOrderByCreatedAtDesc(Long chauffeurId);
}
