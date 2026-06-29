package com.tmk.vtcmanager.interfaces.rest.vehicule.mapper;

import com.tmk.vtcmanager.application.domain.vehicule.StatutVehicule;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.StatutVehiculeResponse;
import org.mapstruct.Mapper;

import java.util.List;

@Mapper(componentModel = "spring")
public interface StatutVehiculeRestMapper {

    StatutVehiculeResponse toResponse(StatutVehicule domain);

    List<StatutVehiculeResponse> toResponseList(List<StatutVehicule> domains);
}
