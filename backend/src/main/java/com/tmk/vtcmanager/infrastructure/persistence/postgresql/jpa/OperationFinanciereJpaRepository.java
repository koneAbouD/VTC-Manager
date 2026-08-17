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
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

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
}
