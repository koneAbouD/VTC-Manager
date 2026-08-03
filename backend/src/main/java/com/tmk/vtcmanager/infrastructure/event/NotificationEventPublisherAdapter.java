package com.tmk.vtcmanager.infrastructure.event;

import com.tmk.vtcmanager.application.domain.notification.event.NotificationCreeeEvent;
import com.tmk.vtcmanager.application.ports.notification.NotificationEventPublisher;
import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Component;

/**
 * Adaptateur du port {@link NotificationEventPublisher} vers les événements
 * applicatifs de Spring. Contrairement aux événements de statut, celui-ci est
 * consommé après validation de la transaction et hors du fil d'exécution
 * appelant : la latence de FCM n'a pas à peser sur l'opération métier.
 */
@Component
@RequiredArgsConstructor
public class NotificationEventPublisherAdapter implements NotificationEventPublisher {

    private final ApplicationEventPublisher eventPublisher;

    @Override
    public void publierNotificationCreee(Long notificationId) {
        if (notificationId == null) return;
        eventPublisher.publishEvent(new NotificationCreeeEvent(notificationId));
    }
}
