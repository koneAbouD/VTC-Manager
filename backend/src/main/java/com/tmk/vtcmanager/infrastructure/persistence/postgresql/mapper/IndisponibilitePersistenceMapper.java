package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.indisponibilite.Indisponibilite;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.IndisponibiliteEntity;
import org.mapstruct.Mapper;

import java.util.List;

@Mapper(componentModel = "spring", uses = {
        ChauffeurPersistenceMapper.class
})
public interface IndisponibilitePersistenceMapper {

    IndisponibiliteEntity toEntity(Indisponibilite domain);

    Indisponibilite toDomain(IndisponibiliteEntity entity);

    List<Indisponibilite> toDomainList(List<IndisponibiliteEntity> entities);
}
