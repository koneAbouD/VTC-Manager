package com.tmk.vtcmanager.application.exception;

/**
 * Levée quand les écritures demandées ne peuvent pas faire l'objet d'un reçu :
 * une annulée, une qui ne règle pas une créance de chauffeur, ou des écritures
 * au nom de chauffeurs différents. Le message dit laquelle et pourquoi.
 */
public class RecuImpossibleException extends RuntimeException {

    public RecuImpossibleException(String message) {
        super(message);
    }
}
