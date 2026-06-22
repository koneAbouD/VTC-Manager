package com.tmk.vtcmanager.application.exception;

public class LigneCotisationDejaSoldeeException extends RuntimeException {

    public LigneCotisationDejaSoldeeException(Long id) {
        super("La ligne de cotisation " + id + " est déjà soldée ou annulée.");
    }
}
