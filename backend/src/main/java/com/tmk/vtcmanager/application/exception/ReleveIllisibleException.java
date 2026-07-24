package com.tmk.vtcmanager.application.exception;

/**
 * Levée lorsqu'un relevé de contraventions reste illisible : aucune couche texte
 * <b>et</b> OCR infructueux (image trop floue / illisible) ou OCR désactivé.
 * L'extraction lit d'abord la couche texte, puis bascule sur l'OCR (Tesseract)
 * pour les scans et photos ; cette exception ne survient que si aucune de ces
 * voies n'aboutit.
 */
public class ReleveIllisibleException extends RuntimeException {

    public ReleveIllisibleException() {
        super("Impossible de lire ce relevé : aucun texte n'a pu en être extrait, même par "
                + "reconnaissance de caractères. Vérifiez que la photo est nette, bien cadrée et "
                + "lisible, puis réessayez.");
    }
}
