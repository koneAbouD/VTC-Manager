package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.cotisation.EncaissementCotisation;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.EncaissementCotisationEntity;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring")
public interface EncaissementCotisationPersistenceMapper {

    @Mapping(target = "ligneCotisationId", source = "ligneCotisation.id")
    @Mapping(target = "operationFinanciereId", source = "operationFinanciere.id")
    EncaissementCotisation toDomain(EncaissementCotisationEntity entity);

    List<EncaissementCotisation> toDomainList(List<EncaissementCotisationEntity> entities);
}
