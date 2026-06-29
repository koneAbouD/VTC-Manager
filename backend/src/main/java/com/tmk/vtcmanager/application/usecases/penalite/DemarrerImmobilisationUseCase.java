package com.tmk.vtcmanager.application.usecases.penalite;

import com.tmk.vtcmanager.application.domain.penalite.LignePenalite;
import com.tmk.vtcmanager.application.domain.penalite.StatutLignePenalite;
import com.tmk.vtcmanager.application.exception.LignePenaliteNotFoundException;
import com.tmk.vtcmanager.application.exception.LignePenaliteNonDemarrableException;
import com.tmk.vtcmanager.application.ports.event.VehiculeStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

@RequiredArgsConstructor
public class DemarrerImmobilisationUseCase {

    private final LignePenaliteRepository lignePenaliteRepository;
    private final VehiculeStatutEventPublisher statutEventPublisher;

    @Transactional
    public LignePenalite executer(Long id) {
        LignePenalite ligne = lignePenaliteRepository.findById(id)
                .orElseThrow(() -> new LignePenaliteNotFoundException(id));

        if (!ligne.isDemarrable()) {
            throw new LignePenaliteNonDemarrableException(id);
        }

        lignePenaliteRepository.updateDebutImmobilisation(id, StatutLignePenalite.EN_COURS, LocalDateTime.now());

        // Immobilisation démarrée → le véhicule doit passer IMMOBILISE.
        statutEventPublisher.publishStatutDirty(ligne.getVehiculeId());
        return lignePenaliteRepository.findById(id).orElseThrow();
    }
}
