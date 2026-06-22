package com.tmk.vtcmanager.application.usecases.penalite;

import com.tmk.vtcmanager.application.domain.penalite.LignePenalite;
import com.tmk.vtcmanager.application.domain.penalite.StatutLignePenalite;
import com.tmk.vtcmanager.application.exception.LignePenaliteNotFoundException;
import com.tmk.vtcmanager.application.exception.LignePenaliteNonExecutableException;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class ExecuterBuzzerUseCase {

    private final LignePenaliteRepository lignePenaliteRepository;

    @Transactional
    public LignePenalite executer(Long id) {
        LignePenalite ligne = lignePenaliteRepository.findById(id)
                .orElseThrow(() -> new LignePenaliteNotFoundException(id));

        if (!ligne.isExecutable()) {
            throw new LignePenaliteNonExecutableException(id);
        }

        lignePenaliteRepository.updateStatut(id, StatutLignePenalite.EXECUTEE);
        return lignePenaliteRepository.findById(id).orElseThrow();
    }
}
