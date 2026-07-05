package com.tmk.vtcmanager.interfaces.rest.indisponibiliteVehicule.mapper;

import com.tmk.vtcmanager.application.domain.indisponibiliteVehicule.IndisponibiliteVehicule;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.interfaces.rest.indisponibiliteVehicule.dto.request.IndisponibiliteVehiculeRequest;
import com.tmk.vtcmanager.interfaces.rest.indisponibiliteVehicule.dto.response.IndisponibiliteVehiculeResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.mapper.VehiculeRestMapper;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.Named;

import java.util.List;

@Mapper(componentModel = "spring", uses = {
        VehiculeRestMapper.class
})
public interface IndisponibiliteVehiculeRestMapper {

    @Mapping(target = "id", ignore = true)
    @Mapping(target = "statut", ignore = true)
    @Mapping(target = "vehicule", source = "vehiculeId", qualifiedByName = "indispoVehiculeFromId")
    IndisponibiliteVehicule toDomain(IndisponibiliteVehiculeRequest request);

    IndisponibiliteVehiculeResponse toResponse(IndisponibiliteVehicule domain);

    List<IndisponibiliteVehiculeResponse> toResponseList(List<IndisponibiliteVehicule> domains);

    @Named("indispoVehiculeFromId")
    default Vehicule indispoVehiculeFromId(Long id) {
        if (id == null) return null;
        return Vehicule.builder().id(id).build();
    }
}
