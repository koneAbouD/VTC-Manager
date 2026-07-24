package com.tmk.vtcmanager.interfaces.rest.vehicule.mapper;

import com.tmk.vtcmanager.application.domain.vehicule.Balise;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.BaliseResponse;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring")
public interface BaliseRestMapper {

    @Mapping(target = "id", source = "baliseId")
    @Mapping(target = "identifiant", ignore = true)
    @Mapping(target = "numeroTelephone", ignore = true)
    @Mapping(target = "actif", constant = "true")
    Balise toBalise(Long baliseId);

    BaliseResponse toResponse(Balise domain);

    List<BaliseResponse> toResponseList(List<Balise> domains);
}
