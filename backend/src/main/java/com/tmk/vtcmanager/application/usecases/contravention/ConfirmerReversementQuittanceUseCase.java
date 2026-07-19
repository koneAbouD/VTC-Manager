package com.tmk.vtcmanager.application.usecases.contravention;

import com.tmk.vtcmanager.application.domain.contravention.Contravention;
import com.tmk.vtcmanager.application.domain.contravention.ContraventionStatus;
import com.tmk.vtcmanager.application.domain.contravention.reversement.ResultatReversementQuittance;
import com.tmk.vtcmanager.application.ports.persistence.ContraventionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

/**
 * Confirme le reversement des contraventions sélectionnées sur une quittance :
 * pour chacune, réutilise {@link ReverseContraventionUseCase} (passage en
 * REVERSE + opération de dépense « Reversement contravention » avec référence
 * quittance). Idempotent : une contravention déjà REVERSE est ignorée. Atomique :
 * un échec annule tout le lot.
 */
@RequiredArgsConstructor
public class ConfirmerReversementQuittanceUseCase {

    private final ContraventionRepository contraventionRepository;
    private final ReverseContraventionUseCase reverseContraventionUseCase;

    @Transactional
    public ResultatReversementQuittance confirmer(List<Long> contraventionIds, String referenceQuittance) {
        int reversees = 0;
        int dejaReversees = 0;
        int ignorees = 0;

        for (Long id : contraventionIds) {
            if (id == null) {
                ignorees++;
                continue;
            }
            Optional<Contravention> found = contraventionRepository.findById(id);
            if (found.isEmpty()) {
                ignorees++;
                continue;
            }
            if (found.get().getStatut() == ContraventionStatus.REVERSE) {
                dejaReversees++;
                continue;
            }
            reverseContraventionUseCase.execute(id, referenceQuittance);
            reversees++;
        }
        return new ResultatReversementQuittance(reversees, dejaReversees, ignorees);
    }
}
