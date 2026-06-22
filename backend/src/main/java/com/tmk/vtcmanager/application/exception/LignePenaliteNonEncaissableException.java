package com.tmk.vtcmanager.application.exception;

public class LignePenaliteNonEncaissableException extends RuntimeException {
    public LignePenaliteNonEncaissableException(Long id) {
        super("La ligne de pénalité " + id + " n'est pas encaissable (type non AMENDE ou statut terminal).");
    }
}
