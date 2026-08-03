package com.tmk.vtcmanager.interfaces.rest.notification.dto.response;

import com.tmk.vtcmanager.application.domain.notification.Notification;

import java.time.LocalDateTime;

public record NotificationResponse(
        Long id,
        String type,
        String titre,
        String corps,
        /** Nommé et chiffré, contrairement au corps : cette route est authentifiée. */
        String detail,
        String entiteType,
        Long entiteId,
        boolean lue,
        LocalDateTime creeLe
) {

    public static NotificationResponse from(Notification n) {
        return new NotificationResponse(
                n.getId(),
                n.getType() != null ? n.getType().name() : null,
                n.getTitre(),
                n.getCorps(),
                n.getDetail(),
                n.getEntiteType(),
                n.getEntiteId(),
                n.isLue(),
                n.getCreeLe());
    }
}
