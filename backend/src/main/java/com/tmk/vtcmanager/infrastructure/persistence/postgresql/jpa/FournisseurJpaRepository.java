package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.FournisseurEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface FournisseurJpaRepository extends JpaRepository<FournisseurEntity, Long> {

    List<FournisseurEntity> findByActifTrueOrderByNomAsc();

    List<FournisseurEntity> findAllByOrderByNomAsc();

    boolean existsByNomIgnoreCase(String nom);
}
