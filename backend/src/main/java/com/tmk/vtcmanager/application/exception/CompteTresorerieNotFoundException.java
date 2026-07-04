package com.tmk.vtcmanager.application.exception;

public class CompteTresorerieNotFoundException extends RuntimeException {

    public CompteTresorerieNotFoundException(Long id) {
        super("Compte de trésorerie introuvable pour l'id " + id);
    }
}
