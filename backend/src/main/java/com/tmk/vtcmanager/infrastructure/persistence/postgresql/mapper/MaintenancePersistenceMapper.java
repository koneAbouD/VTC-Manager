package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.MaintenanceEntity;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring", uses = {VehiculePersistenceMapper.class, DetailMaintenancePersistenceMapper.class, CategorieOperationPersistenceMapper.class, PartenairePersistenceMapper.class})
public interface MaintenancePersistenceMapper {

    MaintenanceEntity toEntity(Maintenance domain);

    // Drapeau de lecture posé par le contrôleur (verrou d'arrêté) : aucune source ici.
    @Mapping(target = "restaurable", ignore = true)
    Maintenance toDomain(MaintenanceEntity entity);

    List<Maintenance> toDomainList(List<MaintenanceEntity> entities);
}
