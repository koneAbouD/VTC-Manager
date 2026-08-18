package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.ports.persistence.ContraventionRepository;
import lombok.RequiredArgsConstructor;

/**
 * Lorsqu'une écriture qui réglait une contravention est contre-passée, la
 * contravention revient à l'état où le versement l'avait trouvée : le montant
 * payé redescend et le statut repasse EN_ATTENTE ou PARTIELLEMENT_PAYE.
 *
 * <p>Sans cela, une amende resterait PAYE alors que le chauffeur n'a plus rien
 * versé : la créance disparaîtrait des relances sans avoir été honorée.
 *
 * <p>No-op pour les opérations sans contravention liée — dont les écritures
 * antérieures au rattachement, qui n'en portent pas.
 */
@RequiredArgsConstructor
public class AnnulationContraventionService {

    private final ContraventionRepository contraventionRepository;

    public void annulerPaiementLie(OperationFinanciere operation) {
        if (operation == null || operation.getContraventionId() == null) {
            return;
        }
        contraventionRepository.findById(operation.getContraventionId())
                .ifPresent(contravention -> {
                    contravention.annulerPaiement(operation.getMontant());
                    contraventionRepository.save(contravention);
                });
    }
}
