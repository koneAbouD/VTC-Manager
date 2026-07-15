package com.tmk.vtcmanager.application.exception;

/** Erreur métier liée à un paiement Mobile Money (initiation, notification…). */
public class PaiementException extends RuntimeException {

    public PaiementException(String message) {
        super(message);
    }
}
