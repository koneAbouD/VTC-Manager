package com.tmk.vtcmanager.interfaces.rest.chauffeur.dto.request;

import jakarta.validation.constraints.Size;

/**
 * Corps optionnel du provisioning d'un compte chauffeur.
 * Si {@code motDePasse} est fourni, il est posé comme mot de passe initial
 * (active immédiatement la connexion par mot de passe) ; sinon un secret
 * aléatoire est utilisé et le chauffeur définira son mot de passe après OTP.
 */
public record ProvisionCompteRequest(
        @Size(min = 6, message = "Le mot de passe doit contenir au moins 6 caractères")
        String motDePasse
) {}
