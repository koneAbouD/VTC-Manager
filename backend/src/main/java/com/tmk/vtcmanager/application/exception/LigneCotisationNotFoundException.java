package com.tmk.vtcmanager.application.exception;

public class LigneCotisationNotFoundException extends RuntimeException {

    public LigneCotisationNotFoundException(Long id) {
        super("Ligne de cotisation introuvable pour l'id " + id);
    }
}
