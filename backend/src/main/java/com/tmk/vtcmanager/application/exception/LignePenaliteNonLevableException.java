package com.tmk.vtcmanager.application.exception;

public class LignePenaliteNonLevableException extends RuntimeException {
    public LignePenaliteNonLevableException(Long id) {
        super("La ligne de pénalité " + id + " ne peut pas être levée (type non IMMOBILISATION ou statut non EN_COURS).");
    }
}
