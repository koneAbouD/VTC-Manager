package com.tmk.vtcmanager.application.usecases.arrete;

import com.tmk.vtcmanager.application.domain.arrete.ArreteCompte;
import com.tmk.vtcmanager.application.ports.document.ArreteDocumentRenderer;
import lombok.RequiredArgsConstructor;

/** Produit le décompte PDF d'un arrêté de compte (enrichi du reste à restituer/dû). */
@RequiredArgsConstructor
public class GetArreteDecompteUseCase {

    private final GetArreteUseCase getArreteUseCase;
    private final ArreteDocumentRenderer arreteDocumentRenderer;

    public byte[] executer(Long arreteId) {
        ArreteCompte arrete = getArreteUseCase.detail(arreteId)
                .orElseThrow(() -> new IllegalArgumentException("Arrêté introuvable : " + arreteId));
        return arreteDocumentRenderer.renderDecomptePdf(arrete);
    }
}
