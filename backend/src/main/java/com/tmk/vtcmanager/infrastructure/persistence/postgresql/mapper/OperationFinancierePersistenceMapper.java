package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.OperationFinanciereEntity;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring", uses = {
        CategorieOperationPersistenceMapper.class,
        SousCategorieOperationPersistenceMapper.class,
        ChauffeurPersistenceMapper.class,
        VehiculePersistenceMapper.class,
        DetailMaintenancePersistenceMapper.class,
        PartenairePersistenceMapper.class
})
public interface OperationFinancierePersistenceMapper {

    OperationFinanciereEntity toEntity(OperationFinanciere domain);

    // Drapeau de lecture posé par le contrôleur (verrou d'arrêté) : aucune source ici.
    @Mapping(target = "annulable", ignore = true)
    OperationFinanciere toDomain(OperationFinanciereEntity entity);

    List<OperationFinanciere> toDomainList(List<OperationFinanciereEntity> entities);
}
