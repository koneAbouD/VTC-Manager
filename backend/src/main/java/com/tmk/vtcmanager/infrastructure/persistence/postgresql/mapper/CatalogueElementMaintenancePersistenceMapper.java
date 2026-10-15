package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.operation.CatalogueElementMaintenance;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.CatalogueElementMaintenanceEntity;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring")
public interface CatalogueElementMaintenancePersistenceMapper {

    @Mapping(target = "marque", ignore = true)
    @Mapping(target = "modele", ignore = true)
    CatalogueElementMaintenanceEntity toEntity(CatalogueElementMaintenance domain);

    @Mapping(target = "marqueNom", source = "marque.nom")
    @Mapping(target = "modeleNom", source = "modele.nom")
    CatalogueElementMaintenance toDomain(CatalogueElementMaintenanceEntity entity);

    List<CatalogueElementMaintenance> toDomainList(List<CatalogueElementMaintenanceEntity> entities);
}
