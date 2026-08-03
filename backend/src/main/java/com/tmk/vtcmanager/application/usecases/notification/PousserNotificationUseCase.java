package com.tmk.vtcmanager.application.usecases.notification;

import com.tmk.vtcmanager.application.domain.notification.DeviceToken;
import com.tmk.vtcmanager.application.domain.notification.Notification;
import com.tmk.vtcmanager.application.domain.notification.ResultatEnvoi;
import com.tmk.vtcmanager.application.ports.notification.PushNotificationPort;
import com.tmk.vtcmanager.application.ports.persistence.DeviceTokenRepository;
import com.tmk.vtcmanager.application.ports.persistence.NotificationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import java.time.LocalDateTime;
import java.util.List;

/**
 * Pousse une notification déjà enregistrée vers les appareils actifs de son
 * destinataire, puis purge ceux que FCM a rejetés.
 *
 * <p>Cette étape est délibérément séparée de l'enregistrement : elle s'exécute
 * hors de la transaction métier, et son échec ne remet rien en cause. Une
 * notification non poussée reste lisible dans le centre de notifications, ce
 * qui est le comportement voulu — un téléphone éteint ne doit pas faire échouer
 * la génération des pénalités.
 */
@Slf4j
@RequiredArgsConstructor
public class PousserNotificationUseCase {

    private final NotificationRepository notificationRepository;
    private final DeviceTokenRepository deviceTokenRepository;
    private final PushNotificationPort pushNotificationPort;

    public void execute(Long notificationId) {
        Notification notification = notificationRepository.findById(notificationId).orElse(null);
        if (notification == null) {
            log.warn("Notification {} introuvable : envoi abandonné", notificationId);
            return;
        }

        List<String> tokens = deviceTokenRepository
                .findActifsByKeycloakUserId(notification.getDestinataireKeycloakId())
                .stream()
                .map(DeviceToken::getToken)
                .toList();

        if (tokens.isEmpty()) {
            log.debug("Aucun appareil enregistré pour le destinataire de la notification {}", notificationId);
            return;
        }

        ResultatEnvoi resultat = pushNotificationPort.envoyer(tokens, notification);

        if (!resultat.tokensInvalides().isEmpty()) {
            deviceTokenRepository.desactiverTokens(resultat.tokensInvalides());
        }

        if (resultat.succes() > 0) {
            notification.setEnvoyeeLe(LocalDateTime.now());
            notificationRepository.save(notification);
        }
    }
}
