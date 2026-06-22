package com.tmk.vtcmanager.application.usecases.operationFinanciere;

import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class ValiderOperationFinanciereUseCase {

    private final OperationFinanciereRepository operationRepository;

    @Transactional
    public OperationFinanciere execute(Long id) {
        OperationFinanciere operation = operationRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Opération", id));

        if (operation.getStatut() == StatutOperation.ANNULEE) {
            throw new IllegalStateException("Impossible de valider une opération annulée.");
        }
        if (operation.getStatut() == StatutOperation.VALIDEE) {
            throw new IllegalStateException("L'opération est déjà validée.");
        }

        operation.setStatut(StatutOperation.VALIDEE);
        return operationRepository.save(operation);
    }
}
