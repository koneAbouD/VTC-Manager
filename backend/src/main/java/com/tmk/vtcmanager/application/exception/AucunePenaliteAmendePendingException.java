package com.tmk.vtcmanager.application.exception;

public class AucunePenaliteAmendePendingException extends RuntimeException {
    public AucunePenaliteAmendePendingException() {
        super("Aucune pénalité de type AMENDE en attente pour ce véhicule ou ce chauffeur.");
    }
}
