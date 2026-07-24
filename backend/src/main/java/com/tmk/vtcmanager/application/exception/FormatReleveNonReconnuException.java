package com.tmk.vtcmanager.application.exception;

/**
 * Levée lorsqu'un document lisible ne correspond pas au format d'un relevé de
 * contraventions : aucun numéro de contravention n'y a été détecté. Le document
 * importé n'est vraisemblablement pas un relevé du Ministère des Transports (CGI)
 * (ex. : une facture, une quittance de paiement ou un tout autre PDF).
 */
public class FormatReleveNonReconnuException extends RuntimeException {

    public FormatReleveNonReconnuException() {
        super("Ce document ne ressemble pas à un relevé de contraventions : aucun numéro de contravention "
                + "n'y a été détecté. Veuillez vérifier que vous importez bien le relevé du Ministère des "
                + "Transports (CGI).");
    }
}
