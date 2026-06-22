package com.tmk.vtcmanager.interfaces.rest.contravention.mapper;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.contravention.Contravention;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.interfaces.rest.chauffeur.mapper.ChauffeurRestMapper;
import com.tmk.vtcmanager.interfaces.rest.contravention.dto.request.ContraventionRequest;
import com.tmk.vtcmanager.interfaces.rest.contravention.dto.response.ContraventionResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.mapper.VehiculeRestMapper;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.Named;

import java.util.List;

@Mapper(componentModel = "spring", uses = {
        ChauffeurRestMapper.class,
        VehiculeRestMapper.class
})
public interface ContraventionRestMapper {

    @Mapping(target = "id", ignore = true)
    @Mapping(target = "statut", ignore = true)
    @Mapping(target = "chauffeur", source = "chauffeurId", qualifiedByName = "contraventionChauffeurFromId")
    @Mapping(target = "vehicule", source = "vehiculeId", qualifiedByName = "contraventionVehiculeFromId")
    Contravention toDomain(ContraventionRequest request);

    ContraventionResponse toResponse(Contravention domain);

    List<ContraventionResponse> toResponseList(List<Contravention> domains);

    @Named("contraventionChauffeurFromId")
    default Chauffeur contraventionChauffeurFromId(Long id) {
        if (id == null) return null;
        return Chauffeur.builder().id(id).build();
    }

    @Named("contraventionVehiculeFromId")
    default Vehicule contraventionVehiculeFromId(Long id) {
        if (id == null) return null;
        return Vehicule.builder().id(id).build();
    }
}
