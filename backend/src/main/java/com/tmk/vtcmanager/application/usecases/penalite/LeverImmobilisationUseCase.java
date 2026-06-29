package com.tmk.vtcmanager.application.usecases.penalite;

import com.tmk.vtcmanager.application.domain.penalite.LignePenalite;
import com.tmk.vtcmanager.application.domain.penalite.StatutLignePenalite;
import com.tmk.vtcmanager.application.exception.LignePenaliteNotFoundException;
import com.tmk.vtcmanager.application.exception.LignePenaliteNonLevableException;
import com.tmk.vtcmanager.application.ports.event.VehiculeStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

@RequiredArgsConstructor
public class LeverImmobilisationUseCase {

    private final LignePenaliteRepository lignePenaliteRepository;
    private final VehiculeStatutEventPublisher statutEventPublisher;

    @Transactional
    public LignePenalite executer(Long id) {
        LignePenalite ligne = lignePenaliteRepository.findById(id)
                .orElseThrow(() -> new LignePenaliteNotFoundException(id));

        if (!ligne.isLevable()) {
            throw new LignePenaliteNonLevableException(id);
        }

        lignePenaliteRepository.updateFinImmobilisation(id, StatutLignePenalite.LEVEE, LocalDateTime.now());

        // Immobilisation levée → recalcul du statut (sortie de IMMOBILISE).
        statutEventPublisher.publishStatutDirty(ligne.getVehiculeId());
        return lignePenaliteRepository.findById(id).orElseThrow();
    }
}
