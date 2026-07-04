package com.tmk.vtcmanager.application.exception;

public class MotifEcartObligatoireException extends RuntimeException {

    public MotifEcartObligatoireException() {
        super("Un motif est obligatoire lorsque le comptage diffère du solde théorique");
    }
}
