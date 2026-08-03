package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.NotificationEntity;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface NotificationJpaRepository extends JpaRepository<NotificationEntity, Long> {

    List<NotificationEntity> findByDestinataireKeycloakIdOrderByCreatedAtDesc(
            String destinataireKeycloakId, Pageable pageable);

    Optional<NotificationEntity>
    findFirstByDestinataireKeycloakIdAndCleGroupeAndLueFalseAndCreatedAtAfterOrderByCreatedAtDesc(
            String destinataireKeycloakId, String cleGroupe, LocalDateTime depuis);

    long countByDestinataireKeycloakIdAndLueFalse(String destinataireKeycloakId);

    @Modifying
    @Query("UPDATE NotificationEntity n SET n.lue = true, n.lueLe = :maintenant "
            + "WHERE n.destinataireKeycloakId = :userId AND n.lue = false")
    int marquerToutesLues(@Param("userId") String userId,
                          @Param("maintenant") LocalDateTime maintenant);
}
