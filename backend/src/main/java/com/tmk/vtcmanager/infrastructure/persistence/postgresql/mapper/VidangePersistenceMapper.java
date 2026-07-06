package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.vehicule.Vidange;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.VidangeEntity;
import org.mapstruct.Mapper;

import java.util.List;

@Mapper(componentModel = "spring")
public interface VidangePersistenceMapper {

    VidangeEntity toEntity(Vidange domain);

    Vidange toDomain(VidangeEntity entity);

    List<Vidange> toDomainList(List<VidangeEntity> entities);
}
