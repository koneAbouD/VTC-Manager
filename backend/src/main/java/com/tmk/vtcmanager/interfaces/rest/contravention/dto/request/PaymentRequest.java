package com.tmk.vtcmanager.interfaces.rest.contravention.dto.request;

import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;

public record PaymentRequest(
        @NotNull BigDecimal montantPaye,
        /** Optionnel : ESPECES par défaut. Détermine le compte de trésorerie mouvementé. */
        ModePaiement modePaiement
) {}