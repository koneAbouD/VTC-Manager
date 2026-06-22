package com.tmk.vtcmanager.interfaces.rest.vehicule.mapper;

import com.tmk.vtcmanager.application.domain.vehicule.TypeVehicule;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.TypeVehiculeResponse;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring")
public interface TypeVehiculeRestMapper {

    @Mapping(target = "id", source = "typeVehiculeId")
    @Mapping(target = "nom", ignore = true)
    @Mapping(target = "description", ignore = true)
    TypeVehicule toTypeVehicule(String typeVehiculeId);

    TypeVehiculeResponse toResponse(TypeVehicule domain);

    List<TypeVehiculeResponse> toResponseList(List<TypeVehicule> domains);
}
