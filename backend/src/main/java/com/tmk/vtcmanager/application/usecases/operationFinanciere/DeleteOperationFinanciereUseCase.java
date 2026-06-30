package com.tmk.vtcmanager.application.usecases.operationFinanciere;

import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.services.AnnulationEncaissementService;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class DeleteOperationFinanciereUseCase {

    private final OperationFinanciereRepository operationRepository;
    private final AnnulationEncaissementService annulationEncaissementService;

    @Transactional
    public void execute(Long id) {
        OperationFinanciere operation = operationRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Opération", id));

        // Si l'opération est un encaissement (recette/cotisation/pénalité), on
        // supprime d'abord l'encaissement sous-jacent (et on recalcule la ligne)
        // afin de lever la contrainte FK fk_encaissements_operation avant la
        // suppression de l'opération elle-même.
        annulationEncaissementService.annulerEncaissementLie(operation);

        operationRepository.deleteById(id);
    }
}
