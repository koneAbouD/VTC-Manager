package com.tmk.vtcmanager.application.domain.payment;

/**
 * Résultat de l'interprétation d'une notification webhook agrégateur :
 * à quel paiement elle se rapporte (par référence locale et/ou référence
 * agrégateur) et le statut à appliquer.
 */
public record NotificationResult(
        String reference,
        String gatewayReference,
        StatutPaiement statut,
        String message
) {}
