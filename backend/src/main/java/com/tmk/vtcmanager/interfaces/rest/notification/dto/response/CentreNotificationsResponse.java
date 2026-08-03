package com.tmk.vtcmanager.interfaces.rest.notification.dto.response;

import java.util.List;

/**
 * Contenu du centre de notifications : la liste et le compte de non-lues.
 *
 * <p>Les deux dans la même réponse, parce que l'application a besoin des deux
 * en même temps — la liste à afficher et le badge à poser sur l'onglet.
 */
public record CentreNotificationsResponse(
        List<NotificationResponse> notifications,
        long nonLues
) {}
