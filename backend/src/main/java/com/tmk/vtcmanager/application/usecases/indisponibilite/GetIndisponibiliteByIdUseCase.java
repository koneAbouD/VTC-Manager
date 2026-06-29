package com.tmk.vtcmanager.application.usecases.indisponibilite;

import com.tmk.vtcmanager.application.domain.indisponibilite.Indisponibilite;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteRepository;
import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
public class GetIndisponibiliteByIdUseCase {

    private final IndisponibiliteRepository indisponibiliteRepository;

    public Indisponibilite execute(Long id) {
        return indisponibiliteRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Indisponibilité", id));
    }
}
