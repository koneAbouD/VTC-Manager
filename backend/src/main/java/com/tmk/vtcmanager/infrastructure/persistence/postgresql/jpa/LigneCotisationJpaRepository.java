package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.LigneCotisationEntity;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Repository
public interface LigneCotisationJpaRepository
        extends JpaRepository<LigneCotisationEntity, Long>,
                JpaSpecificationExecutor<LigneCotisationEntity> {

    @EntityGraph(attributePaths = {"vehicule", "chauffeur", "encaissements"})
    Optional<LigneCotisationEntity> findById(Long id);

    List<LigneCotisationEntity> findByVehiculeIdAndDateCotisation(Long vehiculeId, LocalDate dateCotisation);

    @Query("SELECT l FROM LigneCotisationEntity l WHERE l.vehicule.id = :vehiculeId AND l.dateCotisation = :date " +
           "AND l.statut IN ('EN_ATTENTE', 'PARTIELLEMENT_ENCAISSE')")
    Optional<LigneCotisationEntity> findActiveByVehiculeIdAndDate(
            @Param("vehiculeId") Long vehiculeId, @Param("date") LocalDate date);

    @Query("SELECT l FROM LigneCotisationEntity l WHERE l.chauffeur.id = :chauffeurId AND l.dateCotisation = :date " +
           "AND l.statut IN ('EN_ATTENTE', 'PARTIELLEMENT_ENCAISSE')")
    Optional<LigneCotisationEntity> findActiveByChauffeurIdAndDate(
            @Param("chauffeurId") Long chauffeurId, @Param("date") LocalDate date);

    @Modifying
    @Query("UPDATE LigneCotisationEntity l SET l.statut = :statut, l.montantEncaisse = :montant WHERE l.id = :id")
    void updateStatutAndMontantEncaisse(
            @Param("id") Long id,
            @Param("statut") StatutLigneCotisation statut,
            @Param("montant") BigDecimal montant);
}
