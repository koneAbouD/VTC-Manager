package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.vehicule.TypeActivite;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.TypeActiviteEntity;
import org.mapstruct.Mapper;

import java.util.List;

@Mapper(componentModel = "spring")
public interface TypeActivitePersistenceMapper {

    TypeActiviteEntity toEntity(TypeActivite domain);

    TypeActivite toDomain(TypeActiviteEntity entity);

    List<TypeActivite> toDomainList(List<TypeActiviteEntity> entities);
}