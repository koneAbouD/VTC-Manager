package com.tmk.vtcmanager.application.exception;

/**
 * Levée lorsqu'un PDF lisible ne correspond pas au format d'une quittance de
 * liquidation : aucun numéro de contravention n'y a été détecté. Le document
 * importé n'est vraisemblablement pas une quittance QuiPux/DGI (ex. : un reçu
 * de paiement de taxes de stationnement).
 */
public class FormatQuittanceNonReconnuException extends RuntimeException {

    public FormatQuittanceNonReconnuException() {
        super("Ce document ne ressemble pas à une quittance de liquidation : aucun numéro de contravention "
                + "n'y a été détecté. Veuillez vérifier que vous importez bien la quittance QuiPux/DGI des "
                + "contraventions réglées.");
    }
}
