package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.configurationRecette.ConfigurationRecette;

import java.util.Optional;

public interface ConfigurationRecetteRepository {

    Optional<ConfigurationRecette> findByVehiculeId(Long vehiculeId);

    ConfigurationRecette save(ConfigurationRecette configurationRecette);
}
