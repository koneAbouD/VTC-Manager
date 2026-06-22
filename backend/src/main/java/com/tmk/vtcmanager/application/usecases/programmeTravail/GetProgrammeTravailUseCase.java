package com.tmk.vtcmanager.application.usecases.programmeTravail;

import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeTravail;
import com.tmk.vtcmanager.application.exception.VehiculeNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.ProgrammeTravailRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
public class GetProgrammeTravailUseCase {

    private final ProgrammeTravailRepository programmeRepository;
    private final VehiculeRepository vehiculeRepository;

    public ProgrammeTravail execute(Long vehiculeId) {
        var vehicule = vehiculeRepository.findById(vehiculeId)
                .orElseThrow(() -> new VehiculeNotFoundException(vehiculeId));

        ProgrammeTravail programme = programmeRepository.findByVehiculeId(vehiculeId)
                .orElseGet(() -> ProgrammeTravail.defaultForVehicule(vehiculeId));
        programme.synchronizeWithCondition(vehicule.getConditionTravail());
        programme.normalize();
        return programme;
    }
}
