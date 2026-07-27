package com.tmk.vtcmanager.application.exception;

import java.time.LocalDate;

/**
 * Écriture refusée parce que la caisse a déjà été comptée pour cette journée.
 */
public class CaisseClotureeException extends RuntimeException {

    public CaisseClotureeException(LocalDate dateEcriture, LocalDate derniereCloture) {
        super("Impossible d'écrire au " + dateEcriture + " sur ce compte : la caisse a été"
                + " clôturée le " + derniereCloture + ". Passez l'écriture à une date postérieure.");
    }
}
