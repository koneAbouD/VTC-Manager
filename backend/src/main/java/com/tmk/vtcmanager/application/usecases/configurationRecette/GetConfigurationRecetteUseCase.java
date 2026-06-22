package com.tmk.vtcmanager.application.usecases.configurationRecette;

import com.tmk.vtcmanager.application.domain.configurationRecette.ConfigurationRecette;
import com.tmk.vtcmanager.application.exception.VehiculeNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.ConfigurationRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
public class GetConfigurationRecetteUseCase {

    private final ConfigurationRecetteRepository configurationRecetteRepository;
    private final VehiculeRepository vehiculeRepository;

    public ConfigurationRecette execute(Long vehiculeId) {
        vehiculeRepository.findById(vehiculeId)
                .orElseThrow(() -> new VehiculeNotFoundException(vehiculeId));

        return configurationRecetteRepository.findByVehiculeId(vehiculeId)
                .orElseGet(() -> ConfigurationRecette.defaultForVehicule(vehiculeId));
    }
}
