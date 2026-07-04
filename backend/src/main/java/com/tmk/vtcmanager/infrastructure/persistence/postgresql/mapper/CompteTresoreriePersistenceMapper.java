package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.tresorerie.CompteTresorerie;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.CompteTresorerieEntity;
import org.mapstruct.Mapper;

import java.util.List;

@Mapper(componentModel = "spring")
public interface CompteTresoreriePersistenceMapper {

    CompteTresorerieEntity toEntity(CompteTresorerie domain);

    CompteTresorerie toDomain(CompteTresorerieEntity entity);

    List<CompteTresorerie> toDomainList(List<CompteTresorerieEntity> entities);
}
