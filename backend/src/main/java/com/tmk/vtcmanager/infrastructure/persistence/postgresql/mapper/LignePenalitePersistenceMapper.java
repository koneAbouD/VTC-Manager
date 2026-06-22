package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.penalite.EncaissementPenalite;
import com.tmk.vtcmanager.application.domain.penalite.LignePenalite;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.EncaissementPenaliteEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.LignePenaliteEntity;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring")
public interface LignePenalitePersistenceMapper {

    @Mapping(target = "vehiculeId", source = "vehicule.id")
    @Mapping(target = "vehiculeImmatriculation", source = "vehicule.immatriculation")
    @Mapping(target = "chauffeurId", source = "chauffeur.id")
    @Mapping(target = "chauffeurNomComplet",
             expression = "java(entity.getChauffeur() != null ? entity.getChauffeur().getPrenom() + \" \" + entity.getChauffeur().getNom() : null)")
    @Mapping(target = "penaliteTemplateId", source = "penaliteTemplate.id")
    @Mapping(target = "ligneRecetteId", source = "ligneRecette.id")
    @Mapping(target = "encaissements", source = "encaissements")
    LignePenalite toDomain(LignePenaliteEntity entity);

    List<LignePenalite> toDomainList(List<LignePenaliteEntity> entities);

    @Mapping(target = "lignePenaliteId", source = "lignePenalite.id")
    @Mapping(target = "operationFinanciereId", source = "operationFinanciere.id")
    EncaissementPenalite toEncaissementDomain(EncaissementPenaliteEntity entity);
}
