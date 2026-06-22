package com.tmk.vtcmanager.application.exception;

public class LigneRecetteDejaSoldeeException extends RuntimeException {

    public LigneRecetteDejaSoldeeException(Long ligneRecetteId) {
        super("La ligne de recette " + ligneRecetteId + " est déjà soldée ou annulée. Aucun encaissement possible.");
    }
}
