package com.tmk.vtcmanager.application.usecases.operationFinanciere;

import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.services.AnnulationEncaissementService;
import com.tmk.vtcmanager.application.services.AnnulationMaintenanceService;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class AnnulerOperationFinanciereUseCase {

    private final OperationFinanciereRepository operationRepository;
    private final AnnulationEncaissementService annulationEncaissementService;
    private final AnnulationMaintenanceService annulationMaintenanceService;

    @Transactional
    public OperationFinanciere execute(Long id) {
        OperationFinanciere operation = operationRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Opération", id));

        if (operation.getStatut() == StatutOperation.ANNULEE) {
            throw new IllegalStateException("L'opération est déjà annulée.");
        }

        operation.setStatut(StatutOperation.ANNULEE);
        OperationFinanciere saved = operationRepository.save(operation);

        // Si l'opération est un encaissement (recette/cotisation/pénalité), on
        // supprime l'encaissement sous-jacent et on recalcule la ligne.
        annulationEncaissementService.annulerEncaissementLie(saved);

        // Si l'opération est une dépense issue d'une maintenance, on rouvre la
        // maintenance (retour à l'état antérieur à la complétion).
        annulationMaintenanceService.reouvrirMaintenanceLiee(saved);

        return saved;
    }
}
