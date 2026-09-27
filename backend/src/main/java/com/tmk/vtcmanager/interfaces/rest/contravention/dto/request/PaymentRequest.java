package com.tmk.vtcmanager.interfaces.rest.contravention.dto.request;

import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.LocalDate;

public record PaymentRequest(
        @NotNull @Positive BigDecimal montantPaye,
        /** Optionnel : ESPECES par défaut. Détermine le compte de trésorerie mouvementé. */
        ModePaiement modePaiement,
        /** Optionnel : jour où l'argent a été reçu, aujourd'hui par défaut. */
        LocalDate dateEncaissement,
        /** Optionnel : n° de transaction Mobile Money. */
        @Size(max = 100) String reference,
        @Size(max = 500) String commentaire
) {}
