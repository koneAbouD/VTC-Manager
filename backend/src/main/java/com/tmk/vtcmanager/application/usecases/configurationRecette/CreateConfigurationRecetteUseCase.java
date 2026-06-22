package com.tmk.vtcmanager.application.usecases.configurationRecette;

import com.tmk.vtcmanager.application.domain.configurationRecette.ConfigurationRecette;
import com.tmk.vtcmanager.application.exception.VehiculeNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.ConfigurationRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class CreateConfigurationRecetteUseCase {

    private final ConfigurationRecetteRepository configurationRecetteRepository;
    private final VehiculeRepository vehiculeRepository;

    @Transactional
    public ConfigurationRecette execute(Long vehiculeId, ConfigurationRecette configurationRecette) {
        vehiculeRepository.findById(vehiculeId)
                .orElseThrow(() -> new VehiculeNotFoundException(vehiculeId));

        if (configurationRecetteRepository.findByVehiculeId(vehiculeId).isPresent()) {
            throw new IllegalArgumentException("Une configuration de recette existe déjà pour ce véhicule. Utilisez la modification.");
        }

        configurationRecette.setVehiculeId(vehiculeId);
        configurationRecette.normalize();
        configurationRecette.validate();

        return configurationRecetteRepository.save(configurationRecette);
    }
}
