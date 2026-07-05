package com.tmk.vtcmanager.application.usecases.penalite;

import com.tmk.vtcmanager.application.domain.penalite.LignePenalite;
import com.tmk.vtcmanager.application.domain.penalite.StatutLignePenalite;
import com.tmk.vtcmanager.application.exception.LignePenaliteDejaTermineeException;
import com.tmk.vtcmanager.application.exception.LignePenaliteNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class AnnulerLignePenaliteUseCase {

    private final LignePenaliteRepository lignePenaliteRepository;

    @Transactional
    public LignePenalite executer(Long id, String motif) {
        LignePenalite ligne = lignePenaliteRepository.findById(id)
                .orElseThrow(() -> new LignePenaliteNotFoundException(id));

        if (ligne.getStatut() == StatutLignePenalite.ANNULEE) {
            return ligne;
        }
        if (ligne.getStatut().isTerminal()) {
            throw new LignePenaliteDejaTermineeException(id);
        }
        if (motif == null || motif.isBlank()) {
            throw new IllegalArgumentException("Le motif d'annulation est obligatoire.");
        }
        if (ligne.aDesVersements()) {
            throw new IllegalStateException(
                    "Impossible d'annuler une ligne ayant déjà des versements. "
                            + "Annulez d'abord les encaissements liés.");
        }

        lignePenaliteRepository.updateStatutEtMotifAnnulation(
                id, StatutLignePenalite.ANNULEE, motif.trim());
        return lignePenaliteRepository.findById(id).orElseThrow();
    }
}
