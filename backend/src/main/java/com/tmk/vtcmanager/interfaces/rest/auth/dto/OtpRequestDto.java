package com.tmk.vtcmanager.interfaces.rest.auth.dto;

import jakarta.validation.constraints.NotBlank;

/** Demande d'envoi d'un code OTP au numéro du chauffeur. */
public record OtpRequestDto(
        @NotBlank(message = "Le numéro de téléphone est requis") String telephone
) {}
