package com.tmk.vtcmanager.application.exception;

public class LigneRecetteNotFoundException extends RuntimeException {

    public LigneRecetteNotFoundException(Long id) {
        super("Ligne de recette introuvable pour l'id " + id);
    }
}
