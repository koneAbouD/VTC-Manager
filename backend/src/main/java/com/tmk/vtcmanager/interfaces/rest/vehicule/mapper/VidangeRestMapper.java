package com.tmk.vtcmanager.interfaces.rest.vehicule.mapper;

import com.tmk.vtcmanager.application.domain.vehicule.Vidange;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.request.VidangeRequest;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.VidangeResponse;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring")
public interface VidangeRestMapper {

    @Mapping(target = "id", ignore = true)
    @Mapping(target = "vehiculeId", ignore = true)
    Vidange toDomain(VidangeRequest request);

    VidangeResponse toResponse(Vidange domain);

    List<VidangeResponse> toResponseList(List<Vidange> domains);
}
