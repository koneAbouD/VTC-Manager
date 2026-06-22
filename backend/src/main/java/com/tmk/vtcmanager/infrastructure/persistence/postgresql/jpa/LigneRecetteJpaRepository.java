package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.LigneRecetteEntity;
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
public interface LigneRecetteJpaRepository
        extends JpaRepository<LigneRecetteEntity, Long>,
                JpaSpecificationExecutor<LigneRecetteEntity> {

    @EntityGraph(attributePaths = {"vehicule", "chauffeur", "encaissements"})
    Optional<LigneRecetteEntity> findById(Long id);

    boolean existsByVehiculeIdAndChauffeurIdAndDateRecette(Long vehiculeId, Long chauffeurId, LocalDate dateRecette);

    Optional<LigneRecetteEntity> findByVehiculeIdAndChauffeurIdAndDateRecette(Long vehiculeId, Long chauffeurId, LocalDate dateRecette);

    List<LigneRecetteEntity> findByVehiculeIdAndDateRecette(Long vehiculeId, LocalDate dateRecette);

    @Query("SELECT l FROM LigneRecetteEntity l WHERE l.vehicule.id = :vehiculeId AND l.dateRecette = :date " +
           "AND l.statut IN ('EN_ATTENTE', 'PARTIELLEMENT_ENCAISSE')")
    Optional<LigneRecetteEntity> findActiveByVehiculeIdAndDate(@Param("vehiculeId") Long vehiculeId, @Param("date") LocalDate date);

    @Query("SELECT l FROM LigneRecetteEntity l WHERE l.chauffeur.id = :chauffeurId AND l.dateRecette = :date " +
           "AND l.statut IN ('EN_ATTENTE', 'PARTIELLEMENT_ENCAISSE')")
    Optional<LigneRecetteEntity> findActiveByChauffeurIdAndDate(@Param("chauffeurId") Long chauffeurId, @Param("date") LocalDate date);

    @Modifying
    @Query("UPDATE LigneRecetteEntity l SET l.statut = :statut, l.montantEncaisse = :montant WHERE l.id = :id")
    void updateStatutAndMontantEncaisse(@Param("id") Long id, @Param("statut") StatutLigneRecette statut, @Param("montant") BigDecimal montant);
}
