package com.tmk.vtcmanager.application.exception;

/**
 * Levée lorsque le fournisseur d'identité (Keycloak) est indisponible ou renvoie
 * une erreur serveur (5xx). Distingue une panne d'infrastructure d'auth d'une
 * erreur applicative (HTTP 503).
 */
public class AuthServiceUnavailableException extends RuntimeException {

    public AuthServiceUnavailableException(String message) {
        super(message);
    }
}
