package com.tmk.vtcmanager.application.ports.document;

import com.tmk.vtcmanager.application.domain.arrete.ArreteCompte;

/** Rendu documentaire d'un arrêté de compte (décompte de restitution). */
public interface ArreteDocumentRenderer {

    /** Produit le décompte PDF de l'arrêté. */
    byte[] renderDecomptePdf(ArreteCompte arrete);
}
