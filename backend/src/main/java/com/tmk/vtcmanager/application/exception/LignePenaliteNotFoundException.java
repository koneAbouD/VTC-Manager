package com.tmk.vtcmanager.application.exception;

public class LignePenaliteNotFoundException extends RuntimeException {
    public LignePenaliteNotFoundException(Long id) {
        super("Ligne de pénalité introuvable : id=" + id);
    }
}
