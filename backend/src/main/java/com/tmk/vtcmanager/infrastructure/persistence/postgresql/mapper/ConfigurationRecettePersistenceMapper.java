package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.configurationRecette.ConfigurationRecette;
import com.tmk.vtcmanager.application.domain.configurationRecette.CotisationRecette;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ConfigurationRecetteEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.CotisationRecetteEntity;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring")
public interface ConfigurationRecettePersistenceMapper {

    @Mapping(target = "vehiculeId", source = "vehicule.id")
    @Mapping(target = "cotisations", source = "cotisations")
    ConfigurationRecette toDomain(ConfigurationRecetteEntity entity);

    List<ConfigurationRecette> toDomainList(List<ConfigurationRecetteEntity> entities);

    CotisationRecette toDomain(CotisationRecetteEntity entity);

    List<CotisationRecette> toCotisationDomainList(List<CotisationRecetteEntity> entities);
}
