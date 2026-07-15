package com.tmk.vtcmanager.application.domain.payment;

import java.math.BigDecimal;

/**
 * Données transmises à l'agrégateur pour initier un paiement.
 * {@code callbackUrl} = URL publique du webhook à notifier.
 */
public record PaiementInitiationCommand(
        String reference,
        BigDecimal montant,
        CanalPaiement canal,
        String telephone,
        String description,
        String callbackUrl
) {}
