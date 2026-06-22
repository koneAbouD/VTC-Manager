package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.vehicule.TypeVehicule;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.TypeVehiculeEntity;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring")
public interface TypeVehiculePersistenceMapper {

    TypeVehiculeEntity toEntity(TypeVehicule domain);

    TypeVehicule toDomain(TypeVehiculeEntity entity);

    List<TypeVehicule> toDomainList(List<TypeVehiculeEntity> entities);
}
