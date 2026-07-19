package com.tmk.vtcmanager.application.exception;

/**
 * Levée lorsqu'une quittance PDF ne contient aucune couche texte exploitable
 * (typiquement un scan ou une photo). L'extraction native (Phase 1) ne peut
 * rien en lire ; le support des documents scannés relève de l'OCR (Phase 2).
 */
public class QuittanceIllisibleException extends RuntimeException {

    public QuittanceIllisibleException() {
        super("Ce PDF ne contient pas de texte exploitable : il s'agit probablement d'un scan ou d'une "
                + "photo. Veuillez importer la quittance au format PDF natif (l'import de documents scannés "
                + "n'est pas encore pris en charge).");
    }
}
