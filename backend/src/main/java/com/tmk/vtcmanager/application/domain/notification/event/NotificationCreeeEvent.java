package com.tmk.vtcmanager.application.domain.notification.event;

/**
 * Signale qu'une notification a été enregistrée et doit maintenant être poussée
 * vers les appareils de son destinataire.
 *
 * <p>L'événement ne porte que l'identifiant : son consommateur s'exécute après
 * la validation de la transaction émettrice, donc la ligne est en base et il la
 * relit. Ce découplage est ce qui garantit qu'aucune notification n'est poussée
 * pour une opération finalement annulée — un chauffeur ne doit pas apprendre
 * une pénalité que le rollback vient d'effacer.
 */
public record NotificationCreeeEvent(Long notificationId) {
}
