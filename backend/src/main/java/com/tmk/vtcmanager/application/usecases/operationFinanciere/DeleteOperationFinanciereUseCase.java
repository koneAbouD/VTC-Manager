package com.tmk.vtcmanager.application.usecases.operationFinanciere;

import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class DeleteOperationFinanciereUseCase {

    private final OperationFinanciereRepository operationRepository;

    @Transactional
    public void execute(Long id) {
        operationRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Opération", id));
        operationRepository.deleteById(id);
    }
}
