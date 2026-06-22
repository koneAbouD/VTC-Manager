package com.tmk.vtcmanager.application.exception;

public class LignePenaliteNonExecutableException extends RuntimeException {
    public LignePenaliteNonExecutableException(Long id) {
        super("La ligne de pénalité " + id + " n'est pas exécutable (type non BUZZER ou statut non EN_ATTENTE).");
    }
}
