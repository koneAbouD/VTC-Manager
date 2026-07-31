package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.operation.ElementMaintenance;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ElementMaintenanceEntity;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring", uses = {
        CatalogueElementMaintenancePersistenceMapper.class,
        PartenairePersistenceMapper.class
})
public interface ElementMaintenancePersistenceMapper {

    /**
     * La quantité passe par son accesseur effectif : une ligne muette vaut un
     * exemplaire, et la colonne n'accepte pas le nul.
     */
    @Mapping(target = "detailMaintenance", ignore = true)
    @Mapping(target = "quantite", expression = "java(domain.getQuantiteEffective())")
    ElementMaintenanceEntity toEntity(ElementMaintenance domain);

    ElementMaintenance toDomain(ElementMaintenanceEntity entity);

    List<ElementMaintenance> toDomainList(List<ElementMaintenanceEntity> entities);
}
