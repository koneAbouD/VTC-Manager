package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.OperationFinanciereEntity;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
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
import java.util.UUID;

@Repository
public interface OperationFinanciereJpaRepository
        extends JpaRepository<OperationFinanciereEntity, Long>,
                JpaSpecificationExecutor<OperationFinanciereEntity> {

    /**
     * Liste filtrée : les cinq associations que le mapper lit pour chaque ligne
     * voyagent avec la page. Sans ce graphe, une page de 20 opérations
     * déclenchait jusqu'à cinq requêtes supplémentaires par ligne.
     */
    @Override
    @EntityGraph(attributePaths = {
            "categorie", "sousCategorie", "chauffeur", "vehicule", "partenaire"})
    Page<OperationFinanciereEntity> findAll(Specification<OperationFinanciereEntity> spec,
                                            Pageable pageable);

    List<OperationFinanciereEntity> findByChauffeurId(Long chauffeurId);

    List<OperationFinanciereEntity> findByVehiculeId(Long vehiculeId);

    boolean existsByReference(String reference);

    List<OperationFinanciereEntity> findByFacturePartenaireIdOrderByDateOperationAscIdAsc(
            Long facturePartenaireId);

    /**
     * Somme des montants d'un type d'opération (REVENU / DEPENSE) sur la période
     * [debut, fin] (bornes incluses), en écartant un statut (ANNULEE).
     *
     * Les deux bornes sont toujours renseignées par l'adapter (dates sentinelles
     * quand la période est ouverte) : on évite ainsi tout test « :param IS NULL »
     * en JPQL, que PostgreSQL refuse sur un paramètre nu (42P18 « could not
     * determine data type of parameter »).
     */
    @Query("""
            SELECT COALESCE(SUM(o.montant), 0)
            FROM OperationFinanciereEntity o
            WHERE o.typeOperation = :type
              AND o.statut <> :statutExclu
              AND o.dateOperation >= :debut
              AND o.dateOperation <= :fin
            """)
    BigDecimal sommeMontantParType(@Param("type") TypeOperation type,
                                   @Param("statutExclu") StatutOperation statutExclu,
                                   @Param("debut") LocalDate debut,
                                   @Param("fin") LocalDate fin);

    /**
     * Passe au nouveau tiers les écritures des versements <b>vivants</b> d'une
     * recette qui vient de changer de débiteur.
     *
     * <p>Trois filtres, chacun pour une raison : l'encaissement doit tenir
     * encore ({@code e.annule_le IS NULL}) ; l'écriture ne doit pas être déjà
     * extournée ni être elle-même une extourne — une écriture contre-passée ne
     * se modifie plus, et le couple qu'elle forme avec son origine s'annule de
     * toute façon, laissant le solde de l'ancien chauffeur intact.
     */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(value = """
            UPDATE operations_financieres o
            SET chauffeur_id = :chauffeurId,
                updated_by   = :auteur,
                updated_at   = now()
            WHERE o.annule_le IS NULL
              AND o.extourne_de_id IS NULL
              AND o.id IN (SELECT e.operation_financiere_id
                           FROM encaissements e
                           WHERE e.ligne_recette_id = :ligneId
                             AND e.annule_le IS NULL
                             AND e.operation_financiere_id IS NOT NULL)
            """, nativeQuery = true)
    int reaffecterChauffeurEncaissementsRecette(@Param("ligneId") Long ligneId,
                                                @Param("chauffeurId") Long chauffeurId,
                                                @Param("auteur") String auteur);

    /** Cf. {@link #reaffecterChauffeurEncaissementsRecette}, côté cotisation. */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(value = """
            UPDATE operations_financieres o
            SET chauffeur_id = :chauffeurId,
                updated_by   = :auteur,
                updated_at   = now()
            WHERE o.annule_le IS NULL
              AND o.extourne_de_id IS NULL
              AND o.id IN (SELECT e.operation_financiere_id
                           FROM encaissements_cotisation e
                           WHERE e.ligne_cotisation_id = :ligneId
                             AND e.annule_le IS NULL
                             AND e.operation_financiere_id IS NOT NULL)
            """, nativeQuery = true)
    int reaffecterChauffeurEncaissementsCotisation(@Param("ligneId") Long ligneId,
                                                   @Param("chauffeurId") Long chauffeurId,
                                                   @Param("auteur") String auteur);

    // ── Versement (pièce de caisse) ─────────────────────────────────────────

    @EntityGraph(attributePaths = {
            "categorie", "sousCategorie", "chauffeur", "vehicule", "partenaire"})
    List<OperationFinanciereEntity> findByVersementIdOrderByIdAsc(UUID versementId);

    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(value = """
            UPDATE operations_financieres
            SET versement_id = :versementId
            WHERE id IN (:ids)
            """, nativeQuery = true)
    int rattacherAuVersement(@Param("ids") List<Long> ids,
                             @Param("versementId") UUID versementId);

    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(value = """
            UPDATE operations_financieres
            SET versement_id = NULL,
                updated_at   = now()
            WHERE versement_id = :versementId
            """, nativeQuery = true)
    int detacherVersement(@Param("versementId") UUID versementId);

    /** Versements touchés par les encaissements d'une recette, défaits d'un coup. */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(value = """
            UPDATE operations_financieres
            SET versement_id = NULL,
                updated_at   = now()
            WHERE versement_id IN (SELECT o.versement_id
                                   FROM operations_financieres o
                                   JOIN encaissements e ON e.operation_financiere_id = o.id
                                   WHERE e.ligne_recette_id = :ligneId
                                     AND o.versement_id IS NOT NULL)
            """, nativeQuery = true)
    int detacherVersementsEncaissementsRecette(@Param("ligneId") Long ligneId);

    /** Cf. {@link #detacherVersementsEncaissementsRecette}, côté cotisation. */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(value = """
            UPDATE operations_financieres
            SET versement_id = NULL,
                updated_at   = now()
            WHERE versement_id IN (SELECT o.versement_id
                                   FROM operations_financieres o
                                   JOIN encaissements_cotisation e ON e.operation_financiere_id = o.id
                                   WHERE e.ligne_cotisation_id = :ligneId
                                     AND o.versement_id IS NOT NULL)
            """, nativeQuery = true)
    int detacherVersementsEncaissementsCotisation(@Param("ligneId") Long ligneId);
}
