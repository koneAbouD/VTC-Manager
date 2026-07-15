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
     * Émet des tokens pour un utilisateur <b>sans mot de passe</b>, via le token
     * exchange Keycloak (impersonation par le service account admin).
     *
     * Utilisé par le flux OTP : non destructif (ne touche pas au mot de passe du
     * chauffeur), ce qui permet la coexistence de l'auth OTP et de l'auth par
     * mot de passe sur un même compte.
     *
     * @param userId identifiant Keycloak de l'utilisateur à impersonaliser.
     */
    TokenResponse exchangeToken(String userId);

    /**
     * Rafraîchit un access token à partir d'un refresh token.
     */
    TokenResponse refreshToken(String refreshToken);

    /**
     * Déconnecte l'utilisateur en invalidant sa session Keycloak.
     */
    void logout(String refreshToken);
}
