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
