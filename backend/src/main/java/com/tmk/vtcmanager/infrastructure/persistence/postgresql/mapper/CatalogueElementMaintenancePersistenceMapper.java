package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.operation.CatalogueElementMaintenance;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.CatalogueElementMaintenanceEntity;
import org.mapstruct.Mapper;

import java.util.List;

@Mapper(componentModel = "spring")
public interface CatalogueElementMaintenancePersistenceMapper {

    CatalogueElementMaintenanceEntity toEntity(CatalogueElementMaintenance domain);

    CatalogueElementMaintenance toDomain(CatalogueElementMaintenanceEntity entity);

    List<CatalogueElementMaintenance> toDomainList(List<CatalogueElementMaintenanceEntity> entities);
}
