package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.vehicule.Balise;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.BaliseEntity;
import org.mapstruct.Mapper;

import java.util.List;

@Mapper(componentModel = "spring")
public interface BalisePersistenceMapper {

    BaliseEntity toEntity(Balise domain);

    Balise toDomain(BaliseEntity entity);

    List<Balise> toDomainList(List<BaliseEntity> entities);
}
