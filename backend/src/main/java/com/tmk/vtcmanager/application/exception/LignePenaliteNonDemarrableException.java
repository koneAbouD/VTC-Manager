package com.tmk.vtcmanager.application.exception;

public class LignePenaliteNonDemarrableException extends RuntimeException {
    public LignePenaliteNonDemarrableException(Long id) {
        super("La ligne de pénalité " + id + " ne peut pas démarrer (type non IMMOBILISATION ou statut non EN_ATTENTE).");
    }
}
