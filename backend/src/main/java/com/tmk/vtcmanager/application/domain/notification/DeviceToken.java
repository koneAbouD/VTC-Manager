package com.tmk.vtcmanager.application.domain.notification;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * Jeton d'enregistrement FCM d'un appareil, rattaché au compte qui y est
 * connecté.
 *
 * <p>Le jeton identifie l'appareil, pas la personne : c'est pourquoi il est
 * unique en base et change de propriétaire quand un autre compte se connecte
 * sur le même téléphone.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DeviceToken {

    private Long id;

    /** Claim {@code sub} du jeton Keycloak du compte connecté. */
    private String keycloakUserId;

    private String token;
    private Plateforme plateforme;
    private ApplicationCliente application;
    private boolean actif;

    /** Dernier enregistrement ou rafraîchissement signalé par l'appareil. */
    private LocalDateTime vuLe;

    public void validate() {
        if (keycloakUserId == null || keycloakUserId.isBlank()) {
            throw new IllegalArgumentException("Le compte destinataire est obligatoire.");
        }
        if (token == null || token.isBlank()) {
            throw new IllegalArgumentException("Le jeton d'appareil est obligatoire.");
        }
        if (plateforme == null) {
            throw new IllegalArgumentException("La plateforme de l'appareil est obligatoire.");
        }
        if (application == null) {
            throw new IllegalArgumentException("L'application d'origine est obligatoire.");
        }
    }
}
