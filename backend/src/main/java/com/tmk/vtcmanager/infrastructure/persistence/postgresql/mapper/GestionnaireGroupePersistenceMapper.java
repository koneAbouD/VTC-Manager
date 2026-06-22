package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.groupe.GestionnaireGroupe;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.GestionnaireGroupeEntity;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring")
public interface GestionnaireGroupePersistenceMapper {

    @Mapping(target = "groupe", ignore = true)
    GestionnaireGroupeEntity toEntity(GestionnaireGroupe domain);

    @Mapping(target = "username", ignore = true)
    GestionnaireGroupe toDomain(GestionnaireGroupeEntity entity);

    List<GestionnaireGroupe> toDomainList(List<GestionnaireGroupeEntity> entities);
}