package com.tmk.vtcmanager.application.usecases.penalite;

import com.tmk.vtcmanager.application.domain.penalite.LignePenalite;
import com.tmk.vtcmanager.application.domain.penalite.StatutLignePenalite;
import com.tmk.vtcmanager.application.exception.LignePenaliteNotFoundException;
import com.tmk.vtcmanager.application.exception.LignePenaliteNonLevableException;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

@RequiredArgsConstructor
public class LeverImmobilisationUseCase {

    private final LignePenaliteRepository lignePenaliteRepository;

    @Transactional
    public LignePenalite executer(Long id) {
        LignePenalite ligne = lignePenaliteRepository.findById(id)
                .orElseThrow(() -> new LignePenaliteNotFoundException(id));

        if (!ligne.isLevable()) {
            throw new LignePenaliteNonLevableException(id);
        }

        lignePenaliteRepository.updateFinImmobilisation(id, StatutLignePenalite.LEVEE, LocalDateTime.now());
        return lignePenaliteRepository.findById(id).orElseThrow();
    }
}
