package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ChauffeurEntity;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring", uses = {VehiculePersistenceMapper.class, GeolocalisationPersistenceMapper.class})
public interface ChauffeurPersistenceMapper {

    @Mapping(target = "geolocalisation.chauffeur", ignore = true)
    @Mapping(target = "vehicule", ignore = true)
    ChauffeurEntity toEntity(Chauffeur domain);

    @Mapping(target = "photoPresignedUrl", ignore = true)
    Chauffeur toDomain(ChauffeurEntity entity);

    List<Chauffeur> toDomainList(List<ChauffeurEntity> entities);
}
