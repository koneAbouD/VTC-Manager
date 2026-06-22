package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ProgrammeTravailEntity;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface ProgrammeTravailJpaRepository extends JpaRepository<ProgrammeTravailEntity, Long> {

    @EntityGraph(attributePaths = {"vehicule", "chauffeurs", "chauffeurs.chauffeur"})
    Optional<ProgrammeTravailEntity> findByVehiculeId(Long vehiculeId);

    // Retourne une List pour éviter NonUniqueResultException en cas de données
    // corrompues (chauffeur présent dans plusieurs programmes), triée par id DESC
    // pour prendre le programme le plus récent en premier.
    @EntityGraph(attributePaths = {"vehicule", "chauffeurs", "chauffeurs.chauffeur"})
    @Query("SELECT DISTINCT p FROM ProgrammeTravailEntity p JOIN p.chauffeurs pc WHERE pc.chauffeur.id = :chauffeurId ORDER BY p.id DESC")
    List<ProgrammeTravailEntity> findByChauffeurId(@Param("chauffeurId") Long chauffeurId);

    @EntityGraph(attributePaths = {"vehicule", "chauffeurs", "chauffeurs.chauffeur"})
    @Query("SELECT DISTINCT p FROM ProgrammeTravailEntity p WHERE SIZE(p.chauffeurs) > 0")
    List<ProgrammeTravailEntity> findAllWithChauffeurs();
}
