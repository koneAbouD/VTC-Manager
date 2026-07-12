package com.tmk.vtcmanager.application.usecases.arrete;

import com.tmk.vtcmanager.application.domain.arrete.ArreteCompte;
import com.tmk.vtcmanager.application.ports.document.ArreteDocumentRenderer;
import com.tmk.vtcmanager.application.ports.persistence.ArreteCompteRepository;
import lombok.RequiredArgsConstructor;

/** Produit le décompte PDF d'un arrêté de compte. */
@RequiredArgsConstructor
public class GetArreteDecompteUseCase {

    private final ArreteCompteRepository arreteCompteRepository;
    private final ArreteDocumentRenderer arreteDocumentRenderer;

    public byte[] executer(Long arreteId) {
        ArreteCompte arrete = arreteCompteRepository.findById(arreteId)
                .orElseThrow(() -> new IllegalArgumentException("Arrêté introuvable : " + arreteId));
        return arreteDocumentRenderer.renderDecomptePdf(arrete);
    }
}
