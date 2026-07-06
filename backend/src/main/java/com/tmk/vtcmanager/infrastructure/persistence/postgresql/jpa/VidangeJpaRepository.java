package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.VidangeEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface VidangeJpaRepository extends JpaRepository<VidangeEntity, Long> {

    List<VidangeEntity> findByVehiculeIdOrderByDateVidangeDescIdDesc(Long vehiculeId);

    Optional<VidangeEntity> findFirstByVehiculeIdOrderByDateVidangeDescIdDesc(Long vehiculeId);

    /**
     * Dernière vidange de chaque véhicule (la plus récemment enregistrée, via
     * {@code MAX(id)}) dont la prochaine vidange est planifiée dans l'intervalle
     * [debut, fin]. Ne retourne que la vidange courante d'un véhicule pour éviter
     * de retomber sur une cible obsolète d'une vidange antérieure.
     */
    @Query("""
            SELECT v FROM VidangeEntity v
            WHERE v.dateProchaineVidange IS NOT NULL
              AND v.dateProchaineVidange BETWEEN :debut AND :fin
              AND v.id = (SELECT MAX(v2.id) FROM VidangeEntity v2
                          WHERE v2.vehiculeId = v.vehiculeId)
            """)
    List<VidangeEntity> findDernieresAvecProchaineEntre(@Param("debut") LocalDate debut,
                                                        @Param("fin") LocalDate fin);

    /**
     * Dernière vidange (la plus récemment enregistrée, via {@code MAX(id)}) de
     * chaque véhicule qui en possède au moins une. Sert à l'état de parc pour
     * détecter les vidanges dues par date ou par kilométrage.
     */
    @Query("""
            SELECT v FROM VidangeEntity v
            WHERE v.id = (SELECT MAX(v2.id) FROM VidangeEntity v2
                          WHERE v2.vehiculeId = v.vehiculeId)
            """)
    List<VidangeEntity> findDernieresParVehicule();
}
