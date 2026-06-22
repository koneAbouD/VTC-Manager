package com.tmk.vtcmanager.interfaces.rest.vehicule.mapper;

import com.tmk.vtcmanager.application.domain.vehicule.Marque;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.MarqueResponse;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring")
public interface MarqueRestMapper {

    @Mapping(target = "id", source = "marqueId")
    @Mapping(target = "nom", ignore = true)
    @Mapping(target = "type", ignore = true)
    @Mapping(target = "paysOrigine", ignore = true)
    Marque toMarque(String marqueId);

    MarqueResponse toResponse(Marque domain);

    List<MarqueResponse> toResponseList(List<Marque> domains);
}
