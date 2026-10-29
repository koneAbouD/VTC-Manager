package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.operation.CatalogueElementMaintenance;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.CatalogueElementMaintenanceEntity;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring")
public interface CatalogueElementMaintenancePersistenceMapper {

    @Mapping(target = "categorieType", ignore = true)
    CatalogueElementMaintenanceEntity toEntity(CatalogueElementMaintenance domain);

    @Mapping(target = "categorieTypeLibelle", source = "categorieType.libelle")
    CatalogueElementMaintenance toDomain(CatalogueElementMaintenanceEntity entity);

    List<CatalogueElementMaintenance> toDomainList(List<CatalogueElementMaintenanceEntity> entities);
}
