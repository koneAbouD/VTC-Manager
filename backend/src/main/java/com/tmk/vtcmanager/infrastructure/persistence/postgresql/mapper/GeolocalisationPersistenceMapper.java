package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.chauffeur.Geolocalisation;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.GeolocalisationEntity;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

@Mapper(componentModel = "spring")
public interface GeolocalisationPersistenceMapper {

    @Mapping(target = "chauffeur", ignore = true)
    GeolocalisationEntity toEntity(Geolocalisation domain);

    Geolocalisation toDomain(GeolocalisationEntity entity);
}
