package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.vehicule.Marque;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.MarqueEntity;
import org.mapstruct.Mapper;

import java.util.List;

@Mapper(componentModel = "spring", uses = {TypeVehiculePersistenceMapper.class})
public interface MarquePersistenceMapper {

    MarqueEntity toEntity(Marque domain);

    Marque toDomain(MarqueEntity entity);

    List<Marque> toDomainList(List<MarqueEntity> entities);
}
