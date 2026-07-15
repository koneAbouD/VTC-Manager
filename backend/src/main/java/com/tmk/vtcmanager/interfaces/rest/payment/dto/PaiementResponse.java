package com.tmk.vtcmanager.interfaces.rest.payment.dto;

import com.tmk.vtcmanager.application.domain.payment.Paiement;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/** Vue d'un paiement pour l'app chauffeur. */
public record PaiementResponse(
        String reference,
        String typeCible,
        Long cibleId,
        BigDecimal montant,
        String canal,
        String telephone,
        String statut,
        String paymentUrl,
        boolean regle,
        String messageErreur,
        LocalDateTime createdAt
) {
    public static PaiementResponse from(Paiement p) {
        return new PaiementResponse(
                p.getReference(),
                p.getTypeCible() != null ? p.getTypeCible().name() : null,
                p.getCibleId(),
                p.getMontant(),
                p.getCanal() != null ? p.getCanal().name() : null,
                p.getTelephone(),
                p.getStatut() != null ? p.getStatut().name() : null,
                p.getPaymentUrl(),
                p.estRegle(),
                p.getMessageErreur(),
                p.getCreatedAt());
    }
}
