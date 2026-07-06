package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.jourFerie.JourFerie;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.JourFerieEntity;
import org.mapstruct.Mapper;

import java.util.List;

@Mapper(componentModel = "spring")
public interface JourFeriePersistenceMapper {

    JourFerieEntity toEntity(JourFerie domain);

    JourFerie toDomain(JourFerieEntity entity);

    List<JourFerie> toDomainList(List<JourFerieEntity> entities);
}
