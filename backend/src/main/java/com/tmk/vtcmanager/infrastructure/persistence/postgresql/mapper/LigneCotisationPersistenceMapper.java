package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.cotisation.EncaissementCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.EncaissementCotisationEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.LigneCotisationEntity;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring")
public interface LigneCotisationPersistenceMapper {

    @Mapping(target = "vehiculeId", source = "vehicule.id")
    @Mapping(target = "vehiculeImmatriculation", source = "vehicule.immatriculation")
    @Mapping(target = "chauffeurId", source = "chauffeur.id")
    @Mapping(target = "encaissements", source = "encaissements")
    LigneCotisation toDomain(LigneCotisationEntity entity);

    List<LigneCotisation> toDomainList(List<LigneCotisationEntity> entities);

    @Mapping(target = "ligneCotisationId", source = "ligneCotisation.id")
    @Mapping(target = "operationFinanciereId", source = "operationFinanciere.id")
    EncaissementCotisation toEncaissementDomain(EncaissementCotisationEntity entity);
}
