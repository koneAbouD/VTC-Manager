package com.tmk.vtcmanager.application.ports.payment;

import com.tmk.vtcmanager.application.domain.payment.InitiationResult;
import com.tmk.vtcmanager.application.domain.payment.NotificationResult;
import com.tmk.vtcmanager.application.domain.payment.PaiementInitiationCommand;
import com.tmk.vtcmanager.application.domain.payment.StatutPaiement;

import java.util.Map;

/**
 * Passerelle de paiement Mobile Money — contrat agnostique de l'agrégateur
 * (CinetPay, PayDunya, Hub2…). Un adapter concret l'implémente ; l'application
 * ne dépend jamais d'un fournisseur particulier.
 */
public interface PaymentGatewayPort {

    /** Initie le paiement auprès de l'agrégateur. */
    InitiationResult initier(PaiementInitiationCommand command);

    /**
     * Interprète une notification webhook (après vérification de signature).
     * @throws com.tmk.vtcmanager.application.exception.PaiementException si la signature est invalide.
     */
    NotificationResult interpreterNotification(String rawPayload, Map<String, String> headers);

    /** Vérifie le statut d'une transaction auprès de l'agrégateur (polling / réconciliation). */
    StatutPaiement verifierStatut(String gatewayReference);
}
