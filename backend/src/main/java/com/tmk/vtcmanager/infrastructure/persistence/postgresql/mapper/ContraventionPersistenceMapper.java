package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.contravention.Contravention;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ContraventionEntity;
import org.mapstruct.Mapper;

import java.util.List;

@Mapper(componentModel = "spring", uses = {
        ChauffeurPersistenceMapper.class,
        VehiculePersistenceMapper.class
})
public interface ContraventionPersistenceMapper {

    ContraventionEntity toEntity(Contravention domain);

    Contravention toDomain(ContraventionEntity entity);

    List<Contravention> toDomainList(List<ContraventionEntity> entities);
}
