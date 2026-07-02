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

    // flush + clear : la suppression d'encaissement est persistée avant l'update,
    // et l'entité ligne périmée est évincée du contexte pour ne pas réécraser la
    // valeur (montant/statut) au commit — sinon l'annulation ne « prend » pas.
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE LigneRecetteEntity l SET l.statut = :statut, l.montantEncaisse = :montant WHERE l.id = :id")
    void updateStatutAndMontantEncaisse(@Param("id") Long id, @Param("statut") StatutLigneRecette statut, @Param("montant") BigDecimal montant);

    /**
     * Recalcule montant_encaisse ET statut d'une ligne DIRECTEMENT depuis la
     * table des encaissements (source de vérité), en une seule instruction
     * atomique. À appeler après tout ajout/suppression d'encaissement.
     * flushAutomatically : rend visibles l'INSERT/DELETE en attente avant le
     * SUM ; clearAutomatically : évince l'entité ligne périmée du contexte.
     * Ne touche pas une ligne annulée.
     */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(value = """
            UPDATE lignes_recette lr
            SET montant_encaisse = sub.total,
                statut = CASE
                    WHEN lr.montant_attendu IS NULL
                        THEN CASE WHEN sub.total > 0 THEN 'PARTIELLEMENT_ENCAISSE' ELSE 'EN_ATTENTE' END
                    WHEN sub.total >= lr.montant_attendu THEN 'ENCAISSE'
                    WHEN sub.total > 0 THEN 'PARTIELLEMENT_ENCAISSE'
                    ELSE 'EN_ATTENTE'
                END
            FROM (SELECT COALESCE(SUM(montant), 0) AS total
                  FROM encaissements WHERE ligne_recette_id = :ligneId) sub
            WHERE lr.id = :ligneId AND lr.statut <> 'ANNULEE'
            """, nativeQuery = true)
    void recalculerDepuisEncaissements(@Param("ligneId") Long ligneId);
}
