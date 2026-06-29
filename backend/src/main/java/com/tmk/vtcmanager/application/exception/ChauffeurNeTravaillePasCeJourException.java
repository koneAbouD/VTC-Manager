package com.tmk.vtcmanager.application.exception;

/**
 * Levée lorsqu'on tente de définir une indisponibilité d'un seul jour pour un
 * chauffeur qui ne travaille pas ce jour-là (selon le programme du véhicule).
 */
public class ChauffeurNeTravaillePasCeJourException extends RuntimeException {

    public ChauffeurNeTravaillePasCeJourException() {
        super("Le chauffeur ne travaille aucun jour de la période sélectionnée : "
                + "aucune indisponibilité n'est nécessaire.");
    }
}
