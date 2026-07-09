package com.tmk.vtcmanager.application.ports.extraction;

import java.io.InputStream;

/**
 * Port d'extraction des contraventions depuis un relevé (PDF natif aujourd'hui,
 * OCR envisageable en implémentation alternative pour les scans/photos).
 */
public interface ContraventionExtractorPort {

    /**
     * Extrait la plaque et les contraventions d'un relevé.
     *
     * @param contenu flux du document (le port ne le ferme pas)
     * @return la plaque et la liste des contraventions ; liste vide si aucune trouvée
     */
    ReleveContraventions extraire(InputStream contenu);
}
