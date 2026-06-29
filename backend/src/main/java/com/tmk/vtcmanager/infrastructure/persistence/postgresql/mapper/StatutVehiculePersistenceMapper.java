package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.vehicule.StatutVehicule;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.StatutVehiculeEntity;
import org.mapstruct.Mapper;

import java.util.List;

@Mapper(componentModel = "spring")
public interface StatutVehiculePersistenceMapper {

    StatutVehiculeEntity toEntity(StatutVehicule domain);

    StatutVehicule toDomain(StatutVehiculeEntity entity);

    List<StatutVehicule> toDomainList(List<StatutVehiculeEntity> entities);
}
