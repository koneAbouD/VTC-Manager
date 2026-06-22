package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.operation.DetailMaintenance;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.DetailMaintenanceEntity;
import org.mapstruct.AfterMapping;
import org.mapstruct.Mapper;
import org.mapstruct.MappingTarget;

@Mapper(componentModel = "spring", uses = {ElementMaintenancePersistenceMapper.class})
public interface DetailMaintenancePersistenceMapper {

    DetailMaintenanceEntity toEntity(DetailMaintenance domain);

    DetailMaintenance toDomain(DetailMaintenanceEntity entity);

    /**
     * Après le mapping, on injecte la référence parent dans chaque élément
     * afin que la colonne detail_maintenance_id (NOT NULL) soit renseignée
     * avant le flush JPA.
     */
    @AfterMapping
    default void linkElementsToDetail(@MappingTarget DetailMaintenanceEntity entity) {
        if (entity.getElements() != null) {
            entity.getElements().forEach(el -> el.setDetailMaintenance(entity));
        }
    }
}
