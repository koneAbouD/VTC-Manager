package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.notification.ApplicationCliente;
import com.tmk.vtcmanager.application.domain.notification.DeviceToken;

import java.util.List;
import java.util.Optional;

public interface DeviceTokenRepository {

    DeviceToken save(DeviceToken deviceToken);

    Optional<DeviceToken> findByToken(String token);

    /** Appareils actifs d'un destinataire : la liste visée par un envoi. */
    List<DeviceToken> findActifsByKeycloakUserId(String keycloakUserId);

    /** Appareils actifs des destinataires donnés, pour un envoi groupé. */
    List<DeviceToken> findActifsByKeycloakUserIds(List<String> keycloakUserIds);

    /**
     * Désactive les jetons rejetés par FCM. Les lignes sont conservées plutôt
     * que supprimées : elles disent qu'un appareil a existé, ce qui aide à
     * comprendre pourquoi quelqu'un ne reçoit plus rien.
     */
    void desactiverTokens(List<String> tokens);

    /** Révocation à la déconnexion : ce compte quitte cet appareil. */
    void desactiverToken(String token);

    /** Coupe tous les appareils d'un compte (désactivation, perte de matériel). */
    void desactiverTousPourUtilisateur(String keycloakUserId, ApplicationCliente application);
}
