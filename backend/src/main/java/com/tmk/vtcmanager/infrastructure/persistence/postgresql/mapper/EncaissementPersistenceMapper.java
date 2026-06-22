package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.recette.Encaissement;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.EncaissementEntity;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring")
public interface EncaissementPersistenceMapper {

    @Mapping(target = "ligneRecetteId", source = "ligneRecette.id")
    @Mapping(target = "operationFinanciereId", source = "operationFinanciere.id")
    Encaissement toDomain(EncaissementEntity entity);

    List<Encaissement> toDomainList(List<EncaissementEntity> entities);
}
