package com.tmk.vtcmanager.application.exception;

public class LignePenaliteDejaTermineeException extends RuntimeException {
    public LignePenaliteDejaTermineeException(Long id) {
        super("La ligne de pénalité " + id + " est déjà clôturée et ne peut plus être modifiée.");
    }
}
