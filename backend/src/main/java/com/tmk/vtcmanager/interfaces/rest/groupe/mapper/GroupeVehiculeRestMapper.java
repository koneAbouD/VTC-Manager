package com.tmk.vtcmanager.interfaces.rest.groupe.mapper;

import com.tmk.vtcmanager.application.domain.groupe.GestionnaireGroupe;
import com.tmk.vtcmanager.application.domain.groupe.GroupeVehicule;
import com.tmk.vtcmanager.interfaces.rest.groupe.dto.AddGestionnaireRequest;
import com.tmk.vtcmanager.interfaces.rest.groupe.dto.GestionnaireGroupeResponse;
import com.tmk.vtcmanager.interfaces.rest.groupe.dto.GroupeVehiculeResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.mapper.TypeActiviteRestMapper;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring", uses = {TypeActiviteRestMapper.class})
public interface GroupeVehiculeRestMapper {

    GroupeVehiculeResponse toResponse(GroupeVehicule domain);

    List<GroupeVehiculeResponse> toResponseList(List<GroupeVehicule> domains);

    GestionnaireGroupeResponse toGestionnaireResponse(GestionnaireGroupe domain);

    @Mapping(target = "id", ignore = true)
    @Mapping(target = "username", ignore = true)
    GestionnaireGroupe toDomain(AddGestionnaireRequest request);
}