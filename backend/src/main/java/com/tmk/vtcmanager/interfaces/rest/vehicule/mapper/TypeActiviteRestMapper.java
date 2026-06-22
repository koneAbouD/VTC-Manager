package com.tmk.vtcmanager.interfaces.rest.vehicule.mapper;

import com.tmk.vtcmanager.application.domain.vehicule.TypeActivite;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.TypeActiviteResponse;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring")
public interface TypeActiviteRestMapper {

    @Mapping(target = "id", source = "typeActiviteId")
    @Mapping(target = "nom", ignore = true)
    @Mapping(target = "description", ignore = true)
    TypeActivite toTypeActivite(String typeActiviteId);

    TypeActiviteResponse toResponse(TypeActivite domain);

    List<TypeActiviteResponse> toResponseList(List<TypeActivite> domains);
}