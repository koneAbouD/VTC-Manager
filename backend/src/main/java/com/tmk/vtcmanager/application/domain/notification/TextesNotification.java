package com.tmk.vtcmanager.application.domain.notification;

/**
 * Titre et corps d'un message. Existe pour que l'appelant puisse fournir deux
 * rédactions d'un même fait — celle du fait isolé, et celle qui vaut quand il
 * en rejoint un autre du même geste (voir le regroupement dans
 * {@code CreerNotificationUseCase}).
 */
public record TextesNotification(String titre, String corps) {}
