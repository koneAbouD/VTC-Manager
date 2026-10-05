package com.tmk.vtcmanager.application.ports.document;

import com.tmk.vtcmanager.application.domain.arrete.ArreteCompte;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;

import java.util.List;

/** Rendu documentaire d'un arrêté de compte (décompte de restitution). */
public interface ArreteDocumentRenderer {

    /**
     * Produit le décompte PDF de l'arrêté, avec les recettes annulées de sa
     * période : elles n'entrent pas dans le calcul, mais le chauffeur doit
     * voir pourquoi un jour ne lui est pas réclamé.
     */
    byte[] renderDecomptePdf(ArreteCompte arrete, List<LigneRecette> recettesAnnulees);

    /** Décompte sans recette annulée. */
    default byte[] renderDecomptePdf(ArreteCompte arrete) {
        return renderDecomptePdf(arrete, List.of());
    }
}
