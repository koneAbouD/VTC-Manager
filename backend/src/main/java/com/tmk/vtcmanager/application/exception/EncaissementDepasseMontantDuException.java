package com.tmk.vtcmanager.application.exception;

import java.math.BigDecimal;

public class EncaissementDepasseMontantDuException extends RuntimeException {

    public EncaissementDepasseMontantDuException(BigDecimal montantRestant) {
        super("Le montant de l'encaissement dépasse le montant restant à percevoir (" + montantRestant + " XOF).");
    }
}
