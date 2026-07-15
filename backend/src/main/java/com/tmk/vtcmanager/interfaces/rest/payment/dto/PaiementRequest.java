package com.tmk.vtcmanager.interfaces.rest.payment.dto;

import com.tmk.vtcmanager.application.domain.payment.CanalPaiement;
import com.tmk.vtcmanager.application.domain.payment.TypeCiblePaiement;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/** Initiation d'un paiement Mobile Money par le chauffeur. */
public record PaiementRequest(
        @NotNull(message = "Le type de cible est requis") TypeCiblePaiement typeCible,
        @NotNull(message = "La cible est requise") Long cibleId,
        @NotNull(message = "Le canal de paiement est requis") CanalPaiement canal,
        @NotBlank(message = "Le numéro Mobile Money est requis") String telephone
) {}
