package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.MaintenanceEntity;
import org.mapstruct.Mapper;

import java.util.List;

@Mapper(componentModel = "spring", uses = {VehiculePersistenceMapper.class, DetailMaintenancePersistenceMapper.class, CategorieOperationPersistenceMapper.class})
public interface MaintenancePersistenceMapper {

    MaintenanceEntity toEntity(Maintenance domain);

    Maintenance toDomain(MaintenanceEntity entity);

    List<Maintenance> toDomainList(List<MaintenanceEntity> entities);
}
