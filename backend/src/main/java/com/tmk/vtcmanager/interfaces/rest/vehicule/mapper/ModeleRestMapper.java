package com.tmk.vtcmanager.interfaces.rest.vehicule.mapper;

import com.tmk.vtcmanager.application.domain.vehicule.Modele;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.ModeleResponse;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring")
public interface ModeleRestMapper {

    @Mapping(target = "id", source = "modeleId")
    @Mapping(target = "nom", ignore = true)
    @Mapping(target = "type", ignore = true)
    @Mapping(target = "marque", ignore = true)
    Modele toModele(String modeleId);

    ModeleResponse toResponse(Modele domain);

    List<ModeleResponse> toResponseList(List<Modele> domains);
}
