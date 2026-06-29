package com.tmk.vtcmanager.interfaces.rest.indisponibilite.mapper;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.indisponibilite.Indisponibilite;
import com.tmk.vtcmanager.interfaces.rest.chauffeur.mapper.ChauffeurRestMapper;
import com.tmk.vtcmanager.interfaces.rest.indisponibilite.dto.request.IndisponibiliteRequest;
import com.tmk.vtcmanager.interfaces.rest.indisponibilite.dto.response.IndisponibiliteResponse;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.Named;

import java.util.List;

@Mapper(componentModel = "spring", uses = {
        ChauffeurRestMapper.class
})
public interface IndisponibiliteRestMapper {

    @Mapping(target = "id", ignore = true)
    @Mapping(target = "statut", ignore = true)
    @Mapping(target = "chauffeur", source = "chauffeurId", qualifiedByName = "indispoChauffeurFromId")
    @Mapping(target = "chauffeurRemplacant", source = "chauffeurRemplacantId", qualifiedByName = "indispoChauffeurFromId")
    Indisponibilite toDomain(IndisponibiliteRequest request);

    IndisponibiliteResponse toResponse(Indisponibilite domain);

    List<IndisponibiliteResponse> toResponseList(List<Indisponibilite> domains);

    @Named("indispoChauffeurFromId")
    default Chauffeur indispoChauffeurFromId(Long id) {
        if (id == null) return null;
        return Chauffeur.builder().id(id).build();
    }
}
