package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.operation.DetailMaintenance;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.DetailMaintenanceEntity;
import org.mapstruct.Mapper;

@Mapper(componentModel = "spring", uses = {ElementMaintenancePersistenceMapper.class})
public interface DetailMaintenancePersistenceMapper {

    DetailMaintenanceEntity toEntity(DetailMaintenance domain);

    DetailMaintenance toDomain(DetailMaintenanceEntity entity);
}
