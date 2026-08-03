package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.application.domain.notification.ApplicationCliente;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.DeviceTokenEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface DeviceTokenJpaRepository extends JpaRepository<DeviceTokenEntity, Long> {

    Optional<DeviceTokenEntity> findByToken(String token);

    List<DeviceTokenEntity> findByKeycloakUserIdAndActifTrue(String keycloakUserId);

    List<DeviceTokenEntity> findByKeycloakUserIdInAndActifTrue(List<String> keycloakUserIds);

    @Modifying
    @Query("UPDATE DeviceTokenEntity d SET d.actif = false WHERE d.token IN :tokens")
    int desactiverParTokens(@Param("tokens") List<String> tokens);

    @Modifying
    @Query("UPDATE DeviceTokenEntity d SET d.actif = false "
            + "WHERE d.keycloakUserId = :userId AND d.application = :application")
    int desactiverParUtilisateur(@Param("userId") String userId,
                                 @Param("application") ApplicationCliente application);
}
