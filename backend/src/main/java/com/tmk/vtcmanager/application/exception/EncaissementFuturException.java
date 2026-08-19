package com.tmk.vtcmanager.application.exception;

import java.time.LocalDate;

/**
 * Encaissement refusé parce qu'il est daté dans le futur.
 */
public class EncaissementFuturException extends RuntimeException {

    public EncaissementFuturException(LocalDate dateEncaissement, LocalDate aujourdHui) {
        super("Un encaissement ne peut pas être daté du " + dateEncaissement + " : cette date est"
                + " dans le futur (nous sommes le " + aujourdHui + "). Un encaissement constate de"
                + " l'argent déjà reçu — datez-le du jour où il a été perçu.");
    }
}
