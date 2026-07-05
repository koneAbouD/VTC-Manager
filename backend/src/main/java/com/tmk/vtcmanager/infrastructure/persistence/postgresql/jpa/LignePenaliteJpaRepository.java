package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.application.domain.conditionTravail.TypePenalite;
import com.tmk.vtcmanager.application.domain.conditionTravail.TypeSanction;
import com.tmk.vtcmanager.application.domain.penalite.StatutLignePenalite;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.LignePenaliteEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

public interface LignePenaliteJpaRepository
        extends JpaRepository<LignePenaliteEntity, Long>, JpaSpecificationExecutor<LignePenaliteEntity> {

    @Query("""
            SELECT CASE WHEN COUNT(l) > 0 THEN true ELSE false END
            FROM LignePenaliteEntity l
            WHERE l.typeSanction = :typeSanction
              AND l.statut IN :statuts
              AND (l.vehicule.id = :vehiculeId OR l.chauffeur.id = :chauffeurId)
            """)
    boolean hasAmendePendingByVehiculeOrChauffeur(
            @Param("vehiculeId") Long vehiculeId,
            @Param("chauffeurId") Long chauffeurId,
            @Param("typeSanction") TypeSanction typeSanction,
            @Param("statuts") List<StatutLignePenalite> statuts);

    @Query("""
            SELECT CASE WHEN COUNT(l) > 0 THEN true ELSE false END
            FROM LignePenaliteEntity l
            WHERE l.vehicule.id = :vehiculeId
              AND l.chauffeur.id = :chauffeurId
              AND l.typePenalite = :typePenalite
              AND l.dateFaute = :dateFaute
            """)
    boolean existsDejaGeneree(
            @Param("vehiculeId") Long vehiculeId,
            @Param("chauffeurId") Long chauffeurId,
            @Param("typePenalite") TypePenalite typePenalite,
            @Param("dateFaute") LocalDate dateFaute);

    @Query("""
            SELECT CASE WHEN COUNT(l) > 0 THEN true ELSE false END
            FROM LignePenaliteEntity l
            WHERE l.vehicule.id = :vehiculeId
              AND l.typeSanction = :typeSanction
              AND l.statut = :statut
            """)
    boolean existsImmobilisationActive(
            @Param("vehiculeId") Long vehiculeId,
            @Param("typeSanction") TypeSanction typeSanction,
            @Param("statut") StatutLignePenalite statut);

    @Modifying
    @Query("UPDATE LignePenaliteEntity l SET l.statut = :statut WHERE l.id = :id")
    void updateStatut(@Param("id") Long id, @Param("statut") StatutLignePenalite statut);

    @Modifying
    @Query("UPDATE LignePenaliteEntity l SET l.statut = :statut, l.motifAnnulation = :motif WHERE l.id = :id")
    void updateStatutEtMotifAnnulation(@Param("id") Long id,
                                       @Param("statut") StatutLignePenalite statut,
                                       @Param("motif") String motif);

    // flush + clear : cf. LigneRecetteJpaRepository (évite que l'annulation
    // d'encaissement soit réécrasée par l'entité ligne périmée au commit).
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("""
            UPDATE LignePenaliteEntity l
            SET l.statut = :statut, l.montantEncaisse = :montantEncaisse
            WHERE l.id = :id
            """)
    void updateStatutAndMontantEncaisse(
            @Param("id") Long id,
            @Param("statut") StatutLignePenalite statut,
            @Param("montantEncaisse") BigDecimal montantEncaisse);

    /**
     * Recalcule montant_encaisse + statut d'une pénalité (amende) depuis la
     * table des encaissements pénalité (source de vérité), atomiquement.
     * Ne touche QUE les statuts liés à l'encaissement (EN_ATTENTE /
     * PARTIELLEMENT_ENCAISSEE / ENCAISSEE) pour ne pas écraser un statut de
     * cycle de vie (EXECUTEE, NOTIFIEE, EN_COURS, LEVEE, ANNULEE).
     */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(value = """
            UPDATE lignes_penalite lp
            SET montant_encaisse = sub.total,
                statut = CASE
                    WHEN sub.total >= lp.montant THEN 'ENCAISSEE'
                    WHEN sub.total > 0 THEN 'PARTIELLEMENT_ENCAISSEE'
                    ELSE 'EN_ATTENTE'
                END
            FROM (SELECT COALESCE(SUM(montant), 0) AS total
                  FROM encaissements_penalite WHERE ligne_penalite_id = :ligneId) sub
            WHERE lp.id = :ligneId
              AND lp.statut IN ('EN_ATTENTE', 'PARTIELLEMENT_ENCAISSEE', 'ENCAISSEE')
            """, nativeQuery = true)
    void recalculerDepuisEncaissements(@Param("ligneId") Long ligneId);

    @Modifying
    @Query("""
            UPDATE LignePenaliteEntity l
            SET l.statut = :statut, l.dateDebutImmobilisation = :dateDebut
            WHERE l.id = :id
            """)
    void updateDebutImmobilisation(
            @Param("id") Long id,
            @Param("statut") StatutLignePenalite statut,
            @Param("dateDebut") LocalDateTime dateDebut);

    @Modifying
    @Query("""
            UPDATE LignePenaliteEntity l
            SET l.statut = :statut, l.dateFinImmobilisation = :dateFin
            WHERE l.id = :id
            """)
    void updateFinImmobilisation(
            @Param("id") Long id,
            @Param("statut") StatutLignePenalite statut,
            @Param("dateFin") LocalDateTime dateFin);
}
