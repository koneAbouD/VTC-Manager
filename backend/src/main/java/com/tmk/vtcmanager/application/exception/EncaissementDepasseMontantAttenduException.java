package com.tmk.vtcmanager.application.exception;

import java.math.BigDecimal;

public class EncaissementDepasseMontantAttenduException extends RuntimeException {

    public EncaissementDepasseMontantAttenduException(BigDecimal montantRestant) {
        super("Le montant de l'encaissement dépasse le montant restant à percevoir (" + montantRestant + " XOF).");
    }
}
