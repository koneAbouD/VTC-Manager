package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.parametre.ParametreGeneral;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ParametreGeneralEntity;
import org.mapstruct.Mapper;

import java.util.List;

@Mapper(componentModel = "spring")
public interface ParametreGeneralPersistenceMapper {

    ParametreGeneralEntity toEntity(ParametreGeneral domain);

    ParametreGeneral toDomain(ParametreGeneralEntity entity);

    List<ParametreGeneral> toDomainList(List<ParametreGeneralEntity> entities);
}
