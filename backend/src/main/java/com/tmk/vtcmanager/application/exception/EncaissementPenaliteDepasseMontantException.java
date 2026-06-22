package com.tmk.vtcmanager.application.exception;

import java.math.BigDecimal;

public class EncaissementPenaliteDepasseMontantException extends RuntimeException {
    public EncaissementPenaliteDepasseMontantException(BigDecimal montantRestant) {
        super("Le montant encaissé dépasse le montant restant dû (" + montantRestant + " XOF).");
    }
}
