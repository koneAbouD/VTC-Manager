package com.tmk.vtcmanager.interfaces.rest.auth.dto;

import jakarta.validation.constraints.NotBlank;

/** Vérification d'un code OTP : téléphone + code reçu par WhatsApp. */
public record OtpVerifyDto(
        @NotBlank(message = "Le numéro de téléphone est requis") String telephone,
        @NotBlank(message = "Le code est requis") String code
) {}
