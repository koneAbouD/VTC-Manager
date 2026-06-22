package com.tmk.vtcmanager.interfaces.rest.vehicule.mapper;

import com.tmk.vtcmanager.application.domain.configurationRecette.ConfigurationRecette;
import com.tmk.vtcmanager.application.domain.configurationRecette.CotisationRecette;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.request.ConfigurationRecetteRequest;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.request.CotisationRecetteRequest;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.ConfigurationRecetteResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.CotisationRecetteResponse;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring")
public interface ConfigurationRecetteRestMapper {

    @Mapping(target = "id", ignore = true)
    @Mapping(target = "vehiculeId", ignore = true)
    @Mapping(target = "cotisations", source = "cotisations")
    ConfigurationRecette toDomain(ConfigurationRecetteRequest request);

    @Mapping(target = "id", ignore = true)
    CotisationRecette toDomain(CotisationRecetteRequest request);

    @Mapping(target = "cotisations", source = "cotisations")
    ConfigurationRecetteResponse toResponse(ConfigurationRecette domain);

    CotisationRecetteResponse toResponse(CotisationRecette domain);

    List<CotisationRecetteResponse> toResponseList(List<CotisationRecette> domains);
}
