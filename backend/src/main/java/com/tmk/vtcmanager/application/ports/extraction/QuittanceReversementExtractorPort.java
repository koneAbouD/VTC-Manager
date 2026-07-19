package com.tmk.vtcmanager.application.ports.extraction;

import java.io.InputStream;

/**
 * Port d'extraction d'une quittance de paiement de l'État (Phase 1 : PDF natif
 * à couche texte ; une implémentation OCR pour les photos/scans est prévue en
 * Phase 2 sans changer ce contrat).
 */
public interface QuittanceReversementExtractorPort {

    /**
     * Extrait l'en-tête et les lignes réglées d'une quittance.
     *
     * @param contenu flux du document (le port ne le ferme pas)
     * @return l'en-tête et les lignes ; liste de lignes vide si aucune trouvée
     */
    QuittanceReversement extraire(InputStream contenu);
}
