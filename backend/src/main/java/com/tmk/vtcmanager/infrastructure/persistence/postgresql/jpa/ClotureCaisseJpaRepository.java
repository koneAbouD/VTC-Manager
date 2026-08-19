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

    java.util.Optional<ClotureCaisseEntity>
            findFirstByCompteIdAndAnnuleLeIsNullOrderByDateClotureDesc(Long compteId);

    /**
     * Dernier comptage toutes caisses confondues : jusqu'à cette date incluse,
     * les journées sont arrêtées pour toute l'entreprise et ce qui les datait
     * ne peut plus changer sans faire mentir un procès-verbal signé.
     */
    java.util.Optional<ClotureCaisseEntity>
            findFirstByAnnuleLeIsNullOrderByDateClotureDesc();
}
