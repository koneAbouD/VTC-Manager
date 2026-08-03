package com.tmk.vtcmanager.application.domain.notification;

import java.util.List;

/**
 * Bilan d'un envoi push.
 *
 * <p>{@code tokensInvalides} porte les jetons que FCM a définitivement rejetés
 * (application désinstallée, jeton remplacé). L'appelant les désactive : sans
 * cette purge, le parc se remplit d'appareils fantômes vers lesquels chaque
 * envoi ultérieur perd un aller-retour réseau.
 */
public record ResultatEnvoi(
        int succes,
        int echecs,
        List<String> tokensInvalides
) {

    public static ResultatEnvoi aucunDestinataire() {
        return new ResultatEnvoi(0, 0, List.of());
    }
}
