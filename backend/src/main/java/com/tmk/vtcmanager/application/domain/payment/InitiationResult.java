package com.tmk.vtcmanager.application.domain.payment;

/**
 * Résultat de l'initiation côté agrégateur.
 * {@code paymentUrl} est renseigné pour les paiements par redirection (nullable
 * pour un push USSD/STK direct).
 */
public record InitiationResult(
        String gatewayReference,
        StatutPaiement statut,
        String paymentUrl,
        String message
) {}
