package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.groupe.GroupeVehicule;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.GroupeVehiculeEntity;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring", uses = {TypeActivitePersistenceMapper.class, GestionnaireGroupePersistenceMapper.class})
public interface GroupeVehiculePersistenceMapper {

    GroupeVehiculeEntity toEntity(GroupeVehicule domain);

    @Mapping(target = "nbVehicules", ignore = true)
    GroupeVehicule toDomain(GroupeVehiculeEntity entity);

    List<GroupeVehicule> toDomainList(List<GroupeVehiculeEntity> entities);
}