package com.tmk.vtcmanager.application.usecases.operationFinanciere;

import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class UpdateOperationFinanciereUseCase {

    private final OperationFinanciereRepository operationRepository;

    @Transactional
    public OperationFinanciere execute(Long id, OperationFinanciere data) {
        OperationFinanciere existing = operationRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Opération", id));

        if (existing.getStatut() == StatutOperation.ANNULEE) {
            throw new IllegalStateException("Impossible de modifier une opération annulée.");
        }

        existing.setTypeOperation(data.getTypeOperation());
        existing.setCategorie(data.getCategorie());
        existing.setSousCategorie(data.getSousCategorie());
        existing.setChauffeur(data.getChauffeur());
        existing.setVehicule(data.getVehicule());
        existing.setModePaiement(data.getModePaiement());
        existing.setDateOperation(data.getDateOperation());
        existing.setCommentaire(data.getCommentaire());
        existing.setDetailMaintenance(data.getDetailMaintenance());

        // Recalcul montant si maintenance
        if (data.getDetailMaintenance() != null
                && data.getDetailMaintenance().getElements() != null
                && !data.getDetailMaintenance().getElements().isEmpty()) {
            var total = data.getDetailMaintenance().getElements().stream()
                    .map(e -> e.getMontant() != null ? e.getMontant() : java.math.BigDecimal.ZERO)
                    .reduce(java.math.BigDecimal.ZERO, java.math.BigDecimal::add);
            existing.setMontant(total);
        } else {
            existing.setMontant(data.getMontant());
        }

        return operationRepository.save(existing);
    }
}
