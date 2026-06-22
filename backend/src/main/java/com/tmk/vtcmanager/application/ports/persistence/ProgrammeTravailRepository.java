package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeTravail;

import java.util.List;
import java.util.Optional;

public interface ProgrammeTravailRepository {

    Optional<ProgrammeTravail> findByVehiculeId(Long vehiculeId);

    Optional<ProgrammeTravail> findByChauffeurId(Long chauffeurId);

    List<ProgrammeTravail> findAllWithChauffeurs();

    ProgrammeTravail save(ProgrammeTravail programme);
}
