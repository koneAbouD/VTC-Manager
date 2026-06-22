package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.VehiculeEntity;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring", uses = {TypeVehiculePersistenceMapper.class, TypeActivitePersistenceMapper.class, MarquePersistenceMapper.class, ModelePersistenceMapper.class, GroupeVehiculePersistenceMapper.class, ConditionTravailPersistenceMapper.class})
public interface VehiculePersistenceMapper {

    @Mapping(target = "conditionTravail", ignore = true)
    VehiculeEntity toEntity(Vehicule domain);

    @Mapping(target = "photos", ignore = true)
    Vehicule toDomain(VehiculeEntity entity);

    List<Vehicule> toDomainList(List<VehiculeEntity> entities);
}
