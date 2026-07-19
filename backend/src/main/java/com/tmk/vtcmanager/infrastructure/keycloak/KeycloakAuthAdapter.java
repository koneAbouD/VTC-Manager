package com.tmk.vtcmanager.infrastructure.keycloak;

import com.tmk.vtcmanager.application.domain.auth.TokenResponse;
import com.tmk.vtcmanager.application.exception.AuthServiceUnavailableException;
import com.tmk.vtcmanager.application.exception.SessionExpiredException;
import com.tmk.vtcmanager.application.ports.auth.KeycloakAuthPort;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Component;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

import java.util.Map;

/**
 * Adapter pour les opérations d'authentification Keycloak (token endpoint).
 * Utilise le grant_type=password pour le login (Resource Owner Password Credentials).
 */
@Slf4j
@Component
public class KeycloakAuthAdapter implements KeycloakAuthPort {

    private final RestTemplate restTemplate;
    private final String tokenUrl;
    private final String clientId;
    private final String clientSecret;
    private final String adminClientId;
    private final String adminClientSecret;

    public KeycloakAuthAdapter(
            RestTemplate restTemplate,
            @Value("${app.keycloak.auth-server-url}") String authServerUrl,
            @Value("${app.keycloak.realm}") String realm,
            @Value("${app.keycloak.client-id}") String clientId,
            @Value("${app.keycloak.client-secret}") String clientSecret,
            @Value("${app.keycloak.admin.client-id}") String adminClientId,
            @Value("${app.keycloak.admin.client-secret}") String adminClientSecret) {
        this.restTemplate = restTemplate;
        this.tokenUrl = authServerUrl + "/realms/" + realm + "/protocol/openid-connect/token";
        this.clientId = clientId;
        this.clientSecret = clientSecret;
        this.adminClientId = adminClientId;
        this.adminClientSecret = adminClientSecret;
    }

    @Override
    public TokenResponse login(String username, String password) {
        MultiValueMap<String, String> form = new LinkedMultiValueMap<>();
        form.add("grant_type", "password");
        form.add("client_id", clientId);
        form.add("client_secret", clientSecret);
        form.add("username", username);
        form.add("password", password);

        return exchangeToken(form, false);
    }

    @Override
    public TokenResponse exchangeToken(String userId) {
        // Token exchange interne (impersonation) : le service account admin
        // demande des tokens pour le compte du chauffeur, sans mot de passe.
        // Prérequis Keycloak : feature `token-exchange` activée + client admin
        // autorisé à impersonaliser (rôle `impersonation`).
        MultiValueMap<String, String> form = new LinkedMultiValueMap<>();
        form.add("grant_type", "urn:ietf:params:oauth:grant-type:token-exchange");
        form.add("client_id", adminClientId);
        form.add("client_secret", adminClientSecret);
        form.add("requested_subject", userId);
        form.add("audience", clientId);
        form.add("requested_token_type", "urn:ietf:params:oauth:token-type:refresh_token");

        return exchangeToken(form, false);
    }

    @Override
    public TokenResponse refreshToken(String refreshToken) {
        MultiValueMap<String, String> form = new LinkedMultiValueMap<>();
        form.add("grant_type", "refresh_token");
        form.add("client_id", clientId);
        form.add("client_secret", clientSecret);
        form.add("refresh_token", refreshToken);

        return exchangeToken(form, true);
    }

    @Override
    public void logout(String refreshToken) {
        String logoutUrl = tokenUrl.replace("/token", "/logout");

        MultiValueMap<String, String> form = new LinkedMultiValueMap<>();
        form.add("client_id", clientId);
        form.add("client_secret", clientSecret);
        form.add("refresh_token", refreshToken);

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);

        try {
            restTemplate.postForEntity(logoutUrl, new HttpEntity<>(form, headers), Void.class);
            log.info("Utilisateur déconnecté avec succès");
        } catch (HttpClientErrorException e) {
            log.error("Erreur lors du logout Keycloak: {}", e.getResponseBodyAsString());
            throw new RuntimeException("Erreur lors de la déconnexion: " + e.getMessage());
        }
    }

    @SuppressWarnings("unchecked")
    private TokenResponse exchangeToken(MultiValueMap<String, String> form, boolean isRefresh) {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);

        try {
            ResponseEntity<Map> response = restTemplate.postForEntity(
                    tokenUrl, new HttpEntity<>(form, headers), Map.class);

            Map<String, Object> body = response.getBody();
            if (body == null) {
                throw new RuntimeException("Réponse vide du serveur Keycloak");
            }

            return TokenResponse.builder()
                    .accessToken((String) body.get("access_token"))
                    .refreshToken((String) body.get("refresh_token"))
                    .expiresIn(((Number) body.get("expires_in")).longValue())
                    .refreshExpiresIn(((Number) body.get("refresh_expires_in")).longValue())
                    .tokenType((String) body.get("token_type"))
                    .build();

        } catch (HttpClientErrorException e) {
            log.warn("Erreur Keycloak token ({}): {} - {}",
                    isRefresh ? "refresh" : "login", e.getStatusCode(), e.getResponseBodyAsString());
            // Pour un refresh, toute erreur 4xx (typiquement 400 invalid_grant ou
            // 401) signifie que le refresh token est expiré/invalide → 401.
            if (isRefresh) {
                throw new SessionExpiredException(
                        "Votre session a expiré. Veuillez vous reconnecter.");
            }
            if (e.getStatusCode() == HttpStatus.UNAUTHORIZED) {
                throw new IllegalArgumentException("Identifiants invalides");
            }
            throw new RuntimeException("Erreur d'authentification: " + e.getMessage());
        } catch (org.springframework.web.client.HttpServerErrorException e) {
            // Keycloak lui-même a renvoyé une 5xx (ex. « unknown_error ») : le
            // détail est dans les logs de Keycloak. On journalise sa réponse et
            // on renvoie une indisponibilité de service plutôt qu'un 500 opaque.
            log.error("Keycloak a renvoyé une erreur serveur ({}) : {} - {}",
                    isRefresh ? "refresh" : "login", e.getStatusCode(), e.getResponseBodyAsString());
            throw new AuthServiceUnavailableException(
                    "Le service d'authentification est momentanément indisponible. Réessayez plus tard.");
        } catch (org.springframework.web.client.ResourceAccessException e) {
            // Keycloak injoignable (connexion refusée, timeout DNS/réseau).
            log.error("Keycloak injoignable ({}): {}",
                    isRefresh ? "refresh" : "login", e.getMessage());
            throw new AuthServiceUnavailableException(
                    "Le service d'authentification est injoignable. Réessayez plus tard.");
        }
    }
}
