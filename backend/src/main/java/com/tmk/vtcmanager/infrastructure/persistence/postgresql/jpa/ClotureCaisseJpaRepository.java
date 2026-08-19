package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ClotureCaisseEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

@Repository
public interface ClotureCaisseJpaRepository extends JpaRepository<ClotureCaisseEntity, Long> {

    /**
     * Un relevé annulé ne fait plus foi : il reste au dossier, mais aucun
     * contrôle ne s'appuie sur lui — ni l'unicité de la journée, ni la
     * chronologie des comptages, ni l'exigence de clôture du mois.
     */
    boolean existsByCompteIdAndDateClotureAndAnnuleLeIsNull(Long compteId, LocalDate dateCloture);

    List<ClotureCaisseEntity> findByCompteIdAndAnnuleLeIsNullOrderByDateClotureDesc(Long compteId);

    /**
     * Historique complet d'un compte, retirés compris. Le second critère de tri
     * départage les relevés d'une même journée — une date recomptée après un
     * retrait en porte plusieurs, et les afficher dans le désordre rendrait la
     * succession illisible.
     */
    List<ClotureCaisseEntity> findByCompteIdOrderByDateClotureDescIdDesc(Long compteId);

    java.util.Optional<ClotureCaisseEntity>
            findFirstByCompteIdAndAnnuleLeIsNullOrderByDateClotureDesc(Long compteId);

    /** Dernier comptage en vigueur du compte à une date d'arrêté donnée. */
    java.util.Optional<ClotureCaisseEntity>
            findFirstByCompteIdAndAnnuleLeIsNullAndDateClotureLessThanEqualOrderByDateClotureDesc(
                    Long compteId, LocalDate date);

    /**
     * Dernier comptage toutes caisses confondues : jusqu'à cette date incluse,
     * les journées sont arrêtées pour toute l'entreprise et ce qui les datait
     * ne peut plus changer sans faire mentir un procès-verbal signé.
     */
    java.util.Optional<ClotureCaisseEntity>
            findFirstByAnnuleLeIsNullOrderByDateClotureDesc();

    /** Écarts encore en attente d'imputation, du plus ancien au plus récent. */
    List<ClotureCaisseEntity>
            findByImputationStatutAndAnnuleLeIsNullOrderByDateClotureAsc(
                    com.tmk.vtcmanager.application.domain.tresorerie.StatutImputationEcart statut);

    /** [compteId, dernière date de comptage] pour chaque caisse déjà comptée. */
    @org.springframework.data.jpa.repository.Query("""
            SELECT c.compteId, MAX(c.dateCloture) FROM ClotureCaisseEntity c
             WHERE c.annuleLe IS NULL GROUP BY c.compteId
            """)
    java.util.List<Object[]> dernieresClotureParCompte();
}
