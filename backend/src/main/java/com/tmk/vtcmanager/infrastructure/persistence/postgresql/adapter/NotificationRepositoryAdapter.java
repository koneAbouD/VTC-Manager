package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.notification.Notification;
import com.tmk.vtcmanager.application.ports.persistence.NotificationRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.NotificationJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.NotificationPersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Repository
@RequiredArgsConstructor
public class NotificationRepositoryAdapter implements NotificationRepository {

    private final NotificationJpaRepository jpaRepository;
    private final NotificationPersistenceMapper mapper;

    @Override
    public Notification save(Notification notification) {
        return mapper.toDomain(jpaRepository.save(mapper.toEntity(notification)));
    }

    @Override
    public Optional<Notification> findById(Long id) {
        return jpaRepository.findById(id).map(mapper::toDomain);
    }

    @Override
    public Optional<Notification> findNonLueParCleGroupe(
            String keycloakUserId, String cleGroupe, LocalDateTime depuis) {
        return jpaRepository
                .findFirstByDestinataireKeycloakIdAndCleGroupeAndLueFalseAndCreatedAtAfterOrderByCreatedAtDesc(
                        keycloakUserId, cleGroupe, depuis)
                .map(mapper::toDomain);
    }

    @Override
    public List<Notification> findByDestinataire(String keycloakUserId, int limite) {
        return mapper.toDomainList(jpaRepository.findByDestinataireKeycloakIdOrderByCreatedAtDesc(
                keycloakUserId, PageRequest.of(0, limite)));
    }

    @Override
    public long compterNonLues(String keycloakUserId) {
        return jpaRepository.countByDestinataireKeycloakIdAndLueFalse(keycloakUserId);
    }

    @Override
    @Transactional
    public int marquerToutesLues(String keycloakUserId) {
        return jpaRepository.marquerToutesLues(keycloakUserId, LocalDateTime.now());
    }
}
