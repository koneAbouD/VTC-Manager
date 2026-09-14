package com.tmk.vtcmanager.application.ports.document;

import com.tmk.vtcmanager.application.domain.recu.RecuPaiement;

/** Rendu documentaire du reçu de paiement remis au chauffeur. */
public interface RecuDocumentRenderer {

    /** Produit le reçu PDF. */
    byte[] renderRecuPdf(RecuPaiement recu);
}
