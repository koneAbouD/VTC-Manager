package com.tmk.vtcmanager.application.usecases.notification;

import com.tmk.vtcmanager.application.domain.notification.Notification;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.NotificationRepository;
import lombok.RequiredArgsConstructor;

import java.time.LocalDateTime;

@RequiredArgsConstructor
public class MarquerNotificationLueUseCase {

    private final NotificationRepository repository;

    /**
     * L'identifiant du destinataire vient du jeton, jamais du client : une
     * notification ne peut être marquée lue que par celui à qui elle est
     * adressée. Un identifiant qui ne lui appartient pas est traité comme
     * inexistant, sans révéler qu'il existe ailleurs.
     */
    public Notification execute(String keycloakUserId, Long notificationId) {
        Notification notification = repository.findById(notificationId)
                .filter(n -> n.getDestinataireKeycloakId().equals(keycloakUserId))
                .orElseThrow(() -> ResourceNotFoundException.of("Notification", notificationId));

        if (notification.isLue()) {
            return notification;
        }
        notification.setLue(true);
        notification.setLueLe(LocalDateTime.now());
        return repository.save(notification);
    }

    /** Vide le badge d'un coup, depuis le centre de notifications. */
    public int marquerToutesLues(String keycloakUserId) {
        return repository.marquerToutesLues(keycloakUserId);
    }
}
