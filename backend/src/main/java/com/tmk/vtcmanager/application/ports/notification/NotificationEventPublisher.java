package com.tmk.vtcmanager.application.ports.notification;

/**
 * Port d'émission de la demande d'envoi push, une fois la notification
 * enregistrée.
 */
public interface NotificationEventPublisher {

    void publierNotificationCreee(Long notificationId);
}
