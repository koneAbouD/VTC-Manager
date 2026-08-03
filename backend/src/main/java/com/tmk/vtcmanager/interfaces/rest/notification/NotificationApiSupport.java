package com.tmk.vtcmanager.interfaces.rest.notification;

import com.tmk.vtcmanager.application.domain.notification.ApplicationCliente;
import com.tmk.vtcmanager.application.domain.notification.DeviceToken;
import com.tmk.vtcmanager.application.domain.notification.Notification;
import com.tmk.vtcmanager.application.domain.notification.Plateforme;
import com.tmk.vtcmanager.application.domain.notification.TypeNotification;
import com.tmk.vtcmanager.application.usecases.notification.CreerNotificationUseCase;
import com.tmk.vtcmanager.application.usecases.notification.EnregistrerDeviceTokenUseCase;
import com.tmk.vtcmanager.application.usecases.notification.GetNotificationsUseCase;
import com.tmk.vtcmanager.application.usecases.notification.MarquerNotificationLueUseCase;
import com.tmk.vtcmanager.application.usecases.notification.RevoquerDeviceTokenUseCase;
import com.tmk.vtcmanager.interfaces.rest.common.CurrentUserResolver;
import com.tmk.vtcmanager.interfaces.rest.notification.dto.request.DeviceTokenRequest;
import com.tmk.vtcmanager.interfaces.rest.notification.dto.response.CentreNotificationsResponse;
import com.tmk.vtcmanager.interfaces.rest.notification.dto.response.NotificationResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * Traitement commun aux deux surfaces de notifications, celle du back-office
 * ({@code /api/notifications}) et celle de l'espace chauffeur
 * ({@code /api/me/notifications}).
 *
 * <p>Les deux font exactement la même chose ; ce qui les sépare est le préfixe
 * d'URL, et c'est ce préfixe qui porte la règle de sécurité — {@code /api/me/**}
 * est réservé au rôle CHAUFFEUR, le reste aux comptes de gestion. Deux
 * contrôleurs minces valent mieux qu'un seul qu'il faudrait ouvrir à tous.
 */
@Component
@RequiredArgsConstructor
public class NotificationApiSupport {

    private final CurrentUserResolver currentUserResolver;
    private final CreerNotificationUseCase creerNotificationUseCase;
    private final EnregistrerDeviceTokenUseCase enregistrerDeviceTokenUseCase;
    private final RevoquerDeviceTokenUseCase revoquerDeviceTokenUseCase;
    private final GetNotificationsUseCase getNotificationsUseCase;
    private final MarquerNotificationLueUseCase marquerNotificationLueUseCase;

    public void enregistrerAppareil(DeviceTokenRequest request, ApplicationCliente application) {
        enregistrerDeviceTokenUseCase.execute(DeviceToken.builder()
                .keycloakUserId(currentUserResolver.keycloakUserIdOrThrow())
                .token(request.token())
                .plateforme(Plateforme.valueOf(request.plateforme()))
                .application(application)
                .build());
    }

    public void revoquerAppareil(String token) {
        revoquerDeviceTokenUseCase.execute(currentUserResolver.keycloakUserIdOrThrow(), token);
    }

    public CentreNotificationsResponse centre(Integer limite) {
        String userId = currentUserResolver.keycloakUserIdOrThrow();
        List<NotificationResponse> notifications = getNotificationsUseCase.execute(userId, limite)
                .stream()
                .map(NotificationResponse::from)
                .toList();
        return new CentreNotificationsResponse(notifications, getNotificationsUseCase.compterNonLues(userId));
    }

    public NotificationResponse marquerLue(Long id) {
        return NotificationResponse.from(
                marquerNotificationLueUseCase.execute(currentUserResolver.keycloakUserIdOrThrow(), id));
    }

    public void marquerToutesLues() {
        marquerNotificationLueUseCase.marquerToutesLues(currentUserResolver.keycloakUserIdOrThrow());
    }

    /**
     * Envoi de vérification, adressé à l'appelant lui-même.
     *
     * <p>Il traverse toute la chaîne — enregistrement, événement, push — ce qui
     * permet de contrôler qu'un appareil reçoit bien ses notifications sans
     * attendre qu'un événement métier se produise. Le destinataire étant
     * toujours le porteur du jeton, cette route ne permet de déranger personne
     * d'autre.
     */
    public NotificationResponse envoyerTest() {
        return NotificationResponse.from(creerNotificationUseCase.execute(Notification.builder()
                .destinataireKeycloakId(currentUserResolver.keycloakUserIdOrThrow())
                .type(TypeNotification.TEST)
                .titre("Notification de test")
                .corps("Si vous lisez ceci, les notifications fonctionnent sur cet appareil.")
                .build()));
    }
}
