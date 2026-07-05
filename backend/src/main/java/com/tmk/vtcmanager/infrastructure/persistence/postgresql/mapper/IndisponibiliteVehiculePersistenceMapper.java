package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.indisponibiliteVehicule.IndisponibiliteVehicule;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.IndisponibiliteVehiculeEntity;
import org.mapstruct.Mapper;

import java.util.List;

@Mapper(componentModel = "spring", uses = {
        VehiculePersistenceMapper.class
})
public interface IndisponibiliteVehiculePersistenceMapper {

    IndisponibiliteVehiculeEntity toEntity(IndisponibiliteVehicule domain);

    IndisponibiliteVehicule toDomain(IndisponibiliteVehiculeEntity entity);

    List<IndisponibiliteVehicule> toDomainList(List<IndisponibiliteVehiculeEntity> entities);
}
