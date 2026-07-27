package com.tmk.vtcmanager.application.exception;

/**
 * Modification refusée : l'écriture est figée par un arrêté (période close,
 * caisse comptée) ou par sa propre extourne.
 */
public class EcritureFigeeException extends RuntimeException {

    public EcritureFigeeException(String message) {
        super(message);
    }
}
