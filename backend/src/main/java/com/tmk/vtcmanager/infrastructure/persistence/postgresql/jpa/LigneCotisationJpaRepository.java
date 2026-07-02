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

    // flush + clear : cf. LigneRecetteJpaRepository (évite que l'annulation
    // d'encaissement soit réécrasée par l'entité ligne périmée au commit).
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE LigneCotisationEntity l SET l.statut = :statut, l.montantEncaisse = :montant WHERE l.id = :id")
    void updateStatutAndMontantEncaisse(
            @Param("id") Long id,
            @Param("statut") StatutLigneCotisation statut,
            @Param("montant") BigDecimal montant);

    /**
     * Recalcule montant_encaisse + statut depuis la table des encaissements
     * cotisation (source de vérité), atomiquement. Cf. LigneRecetteJpaRepository.
     */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(value = """
            UPDATE lignes_cotisation lc
            SET montant_encaisse = sub.total,
                statut = CASE
                    WHEN sub.total >= lc.montant_du THEN 'ENCAISSE'
                    WHEN sub.total > 0 THEN 'PARTIELLEMENT_ENCAISSE'
                    ELSE 'EN_ATTENTE'
                END
            FROM (SELECT COALESCE(SUM(montant), 0) AS total
                  FROM encaissements_cotisation WHERE ligne_cotisation_id = :ligneId) sub
            WHERE lc.id = :ligneId AND lc.statut <> 'ANNULEE'
            """, nativeQuery = true)
    void recalculerDepuisEncaissements(@Param("ligneId") Long ligneId);
}
