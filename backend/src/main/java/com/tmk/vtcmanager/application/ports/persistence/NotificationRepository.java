package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.notification.Notification;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface NotificationRepository {

    Notification save(Notification notification);

    Optional<Notification> findById(Long id);

    /**
     * Notification encore non lue portant cette clé de regroupement, si elle a
     * été créée depuis {@code depuis}. Sert à réécrire un message plutôt qu'à
     * en empiler un second pour le même geste.
     */
    Optional<Notification> findNonLueParCleGroupe(String keycloakUserId, String cleGroupe, LocalDateTime depuis);

    /** Flux du centre de notifications : les plus récentes d'abord. */
    List<Notification> findByDestinataire(String keycloakUserId, int limite);

    long compterNonLues(String keycloakUserId);

    /** Tout marquer comme lu, depuis le centre de notifications. */
    int marquerToutesLues(String keycloakUserId);
}
