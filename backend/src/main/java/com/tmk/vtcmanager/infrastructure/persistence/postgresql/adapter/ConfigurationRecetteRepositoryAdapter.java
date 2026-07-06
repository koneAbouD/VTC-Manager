package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.configurationRecette.ConfigurationRecette;
import com.tmk.vtcmanager.application.domain.configurationRecette.CotisationRecette;
import com.tmk.vtcmanager.application.ports.persistence.ConfigurationRecetteRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ConfigurationRecetteEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.CotisationRecetteEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.ConfigurationRecetteJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.VehiculeJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.ConfigurationRecettePersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class ConfigurationRecetteRepositoryAdapter implements ConfigurationRecetteRepository {

    private final ConfigurationRecetteJpaRepository configurationRecetteJpaRepository;
    private final VehiculeJpaRepository vehiculeJpaRepository;
    private final ConfigurationRecettePersistenceMapper mapper;

    @Override
    public Optional<ConfigurationRecette> findByVehiculeId(Long vehiculeId) {
        return configurationRecetteJpaRepository.findByVehiculeId(vehiculeId).map(mapper::toDomain);
    }

    @Override
    @Transactional
    public ConfigurationRecette save(ConfigurationRecette configurationRecette) {
        ConfigurationRecetteEntity entity = configurationRecetteJpaRepository
                .findByVehiculeId(configurationRecette.getVehiculeId())
                .orElseGet(ConfigurationRecetteEntity::new);

        entity.setVehicule(vehiculeJpaRepository.getReferenceById(configurationRecette.getVehiculeId()));
        entity.setModeEncaissement(configurationRecette.getModeEncaissement());
        entity.setTypeRecette(configurationRecette.getTypeRecette());
        entity.setFrequenceVersement(configurationRecette.getFrequenceVersement());
        entity.setHeureLimiteVersement(configurationRecette.getHeureLimiteVersement());
        entity.setMontantObjectifParChauffeur(configurationRecette.getMontantObjectifParChauffeur());
        entity.setMontantJourSalaire(configurationRecette.getMontantJourSalaire());
        entity.setMontantJourFerie(configurationRecette.getMontantJourFerie());

        if (entity.getCotisations() == null) {
            entity.setCotisations(new ArrayList<>());
        }
        entity.getCotisations().clear();

        List<CotisationRecette> cotisations = new ArrayList<>(configurationRecette.getCotisations());
        cotisations.sort(Comparator.comparing(
                cotisation -> cotisation.getOrdre() == null ? Integer.MAX_VALUE : cotisation.getOrdre()
        ));

        for (CotisationRecette cotisation : cotisations) {
            entity.getCotisations().add(CotisationRecetteEntity.builder()
                    .configuration(entity)
                    .nom(cotisation.getNom())
                    .montant(cotisation.getMontant())
                    .ordre(cotisation.getOrdre())
                    .build());
        }

        return mapper.toDomain(configurationRecetteJpaRepository.save(entity));
    }
}
