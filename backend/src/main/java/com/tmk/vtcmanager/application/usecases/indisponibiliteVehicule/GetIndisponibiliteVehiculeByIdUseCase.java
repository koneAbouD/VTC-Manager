package com.tmk.vtcmanager.application.usecases.indisponibiliteVehicule;

import com.tmk.vtcmanager.application.domain.indisponibiliteVehicule.IndisponibiliteVehicule;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteVehiculeRepository;
import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
public class GetIndisponibiliteVehiculeByIdUseCase {

    private final IndisponibiliteVehiculeRepository indisponibiliteVehiculeRepository;

    public IndisponibiliteVehicule execute(Long id) {
        return indisponibiliteVehiculeRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Indisponibilité véhicule", id));
    }
}
