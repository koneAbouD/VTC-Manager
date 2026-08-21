package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.LigneCotisationEntity;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
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

    /** Cf. {@link LigneRecetteJpaRepository#findAll} : évite le N+1 véhicule/chauffeur. */
    @Override
    @EntityGraph(attributePaths = {"vehicule", "chauffeur"})
    Page<LigneCotisationEntity> findAll(Specification<LigneCotisationEntity> spec, Pageable pageable);

    @Override
    @EntityGraph(attributePaths = {"vehicule", "chauffeur"})
    List<LigneCotisationEntity> findAll(Specification<LigneCotisationEntity> spec, Sort sort);

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
                  FROM encaissements_cotisation
                  WHERE ligne_cotisation_id = :ligneId AND annule_le IS NULL) sub
            WHERE lc.id = :ligneId AND lc.statut NOT IN ('ANNULEE', 'RESTITUEE')
            """, nativeQuery = true)
    void recalculerDepuisEncaissements(@Param("ligneId") Long ligneId);

    /**
     * Enregistre la part rendue par un arrêté et rattache la ligne à cet arrêté.
     *
     * <p>Le passage en RESTITUEE est <b>conditionné à une ligne soldée</b> : une
     * cotisation partiellement encaissée doit rester dans
     * {@code v_creances_chauffeurs} pour le reste qu'elle doit. La marquer
     * restituée en entier effacerait cette dette de la balance âgée sans
     * qu'aucune écriture ne l'ait éteinte.
     */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(value = """
            UPDATE lignes_cotisation
            SET montant_restitue = montant_restitue + :montant,
                arrete_id = :arreteId,
                statut = CASE WHEN montant_encaisse >= montant_du THEN 'RESTITUEE' ELSE statut END
            WHERE id = :id
            """, nativeQuery = true)
    void marquerRestituee(@Param("id") Long id, @Param("arreteId") Long arreteId,
                          @Param("montant") BigDecimal montant);

    /**
     * Annule la restitution : reprend la part rendue par cet arrêté, détache
     * l'arrêté et recalcule le statut à partir du montant encaissé (les
     * encaissements de cotisation, eux, sont inchangés).
     *
     * <p>Le statut n'est recalculé que s'il valait RESTITUEE : une ligne restée
     * partiellement encaissée pendant l'arrêté n'a jamais changé d'état, et le
     * recalculer écraserait un statut que d'autres écritures ont pu faire
     * évoluer depuis.
     */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(value = """
            UPDATE lignes_cotisation
            SET montant_restitue = GREATEST(montant_restitue - :montant, 0),
                arrete_id = NULL,
                statut = CASE
                    WHEN statut <> 'RESTITUEE' THEN statut
                    WHEN montant_encaisse >= montant_du THEN 'ENCAISSE'
                    WHEN montant_encaisse > 0 THEN 'PARTIELLEMENT_ENCAISSE'
                    ELSE 'EN_ATTENTE'
                END
            WHERE id = :ligneId
            """, nativeQuery = true)
    void annulerRestitution(@Param("ligneId") Long ligneId, @Param("montant") BigDecimal montant);
}
