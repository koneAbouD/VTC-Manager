package com.tmk.vtcmanager.application.usecases.programmeTravail;

import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeTravail;
import com.tmk.vtcmanager.application.exception.VehiculeNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.ProgrammeTravailRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class InvertProgrammeTravailUseCase {

    private final ProgrammeTravailRepository programmeRepository;
    private final VehiculeRepository vehiculeRepository;

    @Transactional
    public ProgrammeTravail execute(Long vehiculeId) {
        vehiculeRepository.findById(vehiculeId)
                .orElseThrow(() -> new VehiculeNotFoundException(vehiculeId));

        ProgrammeTravail programme = programmeRepository.findByVehiculeId(vehiculeId)
                .orElseThrow(() -> new IllegalArgumentException("Aucun programme configuré pour ce véhicule."));

        programme.invertChauffeurs();
        programme.normalize();
        programme.validate();

        return programmeRepository.save(programme);
    }
}
