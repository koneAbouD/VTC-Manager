package com.tmk.vtcmanager.application.usecases.operationFinanciere;

import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciereFiltres;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import lombok.RequiredArgsConstructor;

import java.util.List;

@RequiredArgsConstructor
public class GetAllOperationsFinancieresUseCase {

    private final OperationFinanciereRepository operationRepository;

    /** Liste complète (utilisée par l'écran d'accueil, non paginé). */
    public List<OperationFinanciere> execute(OperationFinanciereFiltres filtres) {
        return operationRepository.findByCriteres(filtres);
    }

    /** Liste paginée (utilisée par la page Opérations, scroll infini). */
    public PageResult<OperationFinanciere> executePage(OperationFinanciereFiltres filtres, int page, int size) {
        return operationRepository.findPageByCriteres(filtres, page, size);
    }
}
