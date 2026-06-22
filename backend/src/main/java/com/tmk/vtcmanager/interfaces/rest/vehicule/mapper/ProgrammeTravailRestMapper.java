package com.tmk.vtcmanager.interfaces.rest.vehicule.mapper;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeChauffeur;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeTravail;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.request.ProgrammeChauffeurRequest;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.request.ProgrammeTravailRequest;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.ProgrammeChauffeurResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.ProgrammeTravailResponse;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring")
public interface ProgrammeTravailRestMapper {

    @Mapping(target = "id", ignore = true)
    @Mapping(target = "vehiculeId", ignore = true)
    @Mapping(target = "joursTravailSemaine", ignore = true)
    @Mapping(target = "chauffeurs", source = "chauffeurs")
    ProgrammeTravail toDomain(ProgrammeTravailRequest request);

    @Mapping(target = "id", ignore = true)
    @Mapping(target = "chauffeur", expression = "java(chauffeurFromId(request.chauffeurId()))")
    ProgrammeChauffeur toDomain(ProgrammeChauffeurRequest request);

    @Mapping(target = "chauffeurs", source = "chauffeurs")
    ProgrammeTravailResponse toResponse(ProgrammeTravail domain);

    @Mapping(target = "chauffeurId", source = "chauffeur.id")
    @Mapping(target = "nom", source = "chauffeur.nom")
    @Mapping(target = "prenom", source = "chauffeur.prenom")
    @Mapping(target = "nomComplet", expression = "java(programmeChauffeur.getNomComplet())")
    @Mapping(target = "telephone", source = "chauffeur.telephone")
    @Mapping(target = "photoUrl", source = "chauffeur.photoUrl")
    @Mapping(target = "type", source = "chauffeur.type")
    @Mapping(target = "statut", source = "chauffeur.statut")
    ProgrammeChauffeurResponse toResponse(ProgrammeChauffeur programmeChauffeur);

    List<ProgrammeChauffeurResponse> toResponseList(List<ProgrammeChauffeur> chauffeurs);

    default Chauffeur chauffeurFromId(Long id) {
        return Chauffeur.builder().id(id).build();
    }
}
