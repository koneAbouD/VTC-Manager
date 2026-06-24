package com.tmk.vtcmanager.application.exception;

/// Levée lorsqu'un refresh token est invalide ou expiré : la session ne peut
/// plus être renouvelée et l'utilisateur doit se reconnecter (HTTP 401).
public class SessionExpiredException extends RuntimeException {

    public SessionExpiredException(String message) {
        super(message);
    }
}
