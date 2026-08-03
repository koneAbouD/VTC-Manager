package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.notification.ApplicationCliente;
import com.tmk.vtcmanager.application.domain.notification.DeviceToken;
import com.tmk.vtcmanager.application.ports.persistence.DeviceTokenRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.DeviceTokenJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.DeviceTokenPersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

@Repository
@RequiredArgsConstructor
public class DeviceTokenRepositoryAdapter implements DeviceTokenRepository {

    private final DeviceTokenJpaRepository jpaRepository;
    private final DeviceTokenPersistenceMapper mapper;

    @Override
    public DeviceToken save(DeviceToken deviceToken) {
        return mapper.toDomain(jpaRepository.save(mapper.toEntity(deviceToken)));
    }

    @Override
    public Optional<DeviceToken> findByToken(String token) {
        return jpaRepository.findByToken(token).map(mapper::toDomain);
    }

    @Override
    public List<DeviceToken> findActifsByKeycloakUserId(String keycloakUserId) {
        return mapper.toDomainList(jpaRepository.findByKeycloakUserIdAndActifTrue(keycloakUserId));
    }

    @Override
    public List<DeviceToken> findActifsByKeycloakUserIds(List<String> keycloakUserIds) {
        if (keycloakUserIds == null || keycloakUserIds.isEmpty()) {
            return List.of();
        }
        return mapper.toDomainList(jpaRepository.findByKeycloakUserIdInAndActifTrue(keycloakUserIds));
    }

    @Override
    @Transactional
    public void desactiverTokens(List<String> tokens) {
        if (tokens == null || tokens.isEmpty()) {
            return;
        }
        jpaRepository.desactiverParTokens(tokens);
    }

    @Override
    @Transactional
    public void desactiverToken(String token) {
        desactiverTokens(List.of(token));
    }

    @Override
    @Transactional
    public void desactiverTousPourUtilisateur(String keycloakUserId, ApplicationCliente application) {
        jpaRepository.desactiverParUtilisateur(keycloakUserId, application);
    }
}
