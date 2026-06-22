package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.recette.Encaissement;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.EncaissementEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.LigneRecetteEntity;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring")
public interface LigneRecettePersistenceMapper {

    @Mapping(target = "vehiculeId", source = "vehicule.id")
    @Mapping(target = "vehiculeImmatriculation", source = "vehicule.immatriculation")
    @Mapping(target = "chauffeurId", source = "chauffeur.id")
    @Mapping(target = "encaissements", source = "encaissements")
    LigneRecette toDomain(LigneRecetteEntity entity);

    List<LigneRecette> toDomainList(List<LigneRecetteEntity> entities);

    @Mapping(target = "ligneRecetteId", source = "ligneRecette.id")
    @Mapping(target = "operationFinanciereId", source = "operationFinanciere.id")
    Encaissement toEncaissementDomain(EncaissementEntity entity);
}
