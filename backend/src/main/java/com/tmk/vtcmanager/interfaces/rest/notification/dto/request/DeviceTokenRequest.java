package com.tmk.vtcmanager.interfaces.rest.notification.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

/**
 * Enregistrement d'un appareil.
 *
 * <p>L'application d'origine n'est pas demandée au client : elle se déduit de
 * l'URL appelée. Un appareil ne peut donc pas se déclarer comme appartenant à
 * l'autre application.
 */
public record DeviceTokenRequest(

        @NotBlank(message = "Le jeton de l'appareil est obligatoire")
        String token,

        @NotBlank(message = "La plateforme est obligatoire")
        @Pattern(regexp = "ANDROID|IOS", message = "Plateforme invalide : attendu ANDROID ou IOS")
        String plateforme
) {}
