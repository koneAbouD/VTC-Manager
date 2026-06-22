package com.tmk.vtcmanager.application.usecases.operationFinanciere;

import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciereFiltres;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import lombok.RequiredArgsConstructor;

import java.util.List;

@RequiredArgsConstructor
public class GetAllOperationsFinancieresUseCase {

    private final OperationFinanciereRepository operationRepository;

    public List<OperationFinanciere> execute(OperationFinanciereFiltres filtres) {
        return operationRepository.findByCriteres(filtres);
    }
}
