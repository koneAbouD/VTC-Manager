package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeChauffeur;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeTravail;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ChauffeurEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ProgrammeChauffeurEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ProgrammeTravailEntity;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring")
public interface ProgrammeTravailPersistenceMapper {

    @Mapping(target = "vehiculeId", source = "vehicule.id")
    @Mapping(target = "chauffeurs", source = "chauffeurs")
    ProgrammeTravail toDomain(ProgrammeTravailEntity entity);

    List<ProgrammeTravail> toDomainList(List<ProgrammeTravailEntity> entities);

    @Mapping(target = "chauffeur", source = "chauffeur")
    ProgrammeChauffeur toDomain(ProgrammeChauffeurEntity entity);

    @Mapping(target = "id", source = "id")
    @Mapping(target = "nom", source = "nom")
    @Mapping(target = "prenom", source = "prenom")
    @Mapping(target = "telephone", source = "telephone")
    @Mapping(target = "photoUrl", source = "photoUrl")
    @Mapping(target = "type", source = "type")
    @Mapping(target = "statut", source = "statut")
    @Mapping(target = "genre", ignore = true)
    @Mapping(target = "dateNaissance", ignore = true)
    @Mapping(target = "email", ignore = true)
    @Mapping(target = "adresse", ignore = true)
    @Mapping(target = "dateEmbauche", ignore = true)
    @Mapping(target = "geolocalisation", ignore = true)
    @Mapping(target = "vehicule", ignore = true)
    @Mapping(target = "photoPresignedUrl", ignore = true)
    Chauffeur toChauffeurDomain(ChauffeurEntity entity);
}
