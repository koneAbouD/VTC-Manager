package com.tmk.vtcmanager.application.ports.auth;

import com.tmk.vtcmanager.application.domain.auth.TokenResponse;

/**
 * Port pour les opérations d'authentification Keycloak.
 * Le backend est le seul à communiquer avec Keycloak.
 */
public interface KeycloakAuthPort {

    /**
     * Authentifie un utilisateur via Resource Owner Password Credentials Grant.
     */
    TokenResponse login(String username, String password);

    /**
     * Rafraîchit un access token à partir d'un refresh token.
     */
    TokenResponse refreshToken(String refreshToken);

    /**
     * Déconnecte l'utilisateur en invalidant sa session Keycloak.
     */
    void logout(String refreshToken);
}
