package com.tmk.vtcmanager.application.exception;

public class LignePenaliteNonNotifiableException extends RuntimeException {
    public LignePenaliteNonNotifiableException(Long id) {
        super("La ligne de pénalité " + id + " n'est pas notifiable (type non AVERTISSEMENT ou statut non EN_ATTENTE).");
    }
}
