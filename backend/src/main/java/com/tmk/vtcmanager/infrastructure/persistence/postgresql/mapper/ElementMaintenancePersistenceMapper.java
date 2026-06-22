package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.operation.ElementMaintenance;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ElementMaintenanceEntity;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring", uses = {CatalogueElementMaintenancePersistenceMapper.class})
public interface ElementMaintenancePersistenceMapper {

    @Mapping(target = "detailMaintenance", ignore = true)
    ElementMaintenanceEntity toEntity(ElementMaintenance domain);

    ElementMaintenance toDomain(ElementMaintenanceEntity entity);

    List<ElementMaintenance> toDomainList(List<ElementMaintenanceEntity> entities);
}
