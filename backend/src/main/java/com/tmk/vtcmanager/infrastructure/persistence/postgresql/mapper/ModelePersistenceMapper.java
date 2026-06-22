package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.vehicule.Modele;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.MarqueEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ModeleEntity;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.Named;

import java.util.List;

@Mapper(componentModel = "spring", uses = {TypeVehiculePersistenceMapper.class, MarquePersistenceMapper.class})
public interface ModelePersistenceMapper {

    ModeleEntity toEntity(Modele domain);

    Modele toDomain(ModeleEntity entity);

    List<Modele> toDomainList(List<ModeleEntity> entities);
}
