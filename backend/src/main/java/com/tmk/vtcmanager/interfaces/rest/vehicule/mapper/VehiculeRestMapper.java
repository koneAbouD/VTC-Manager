package com.tmk.vtcmanager.interfaces.rest.vehicule.mapper;

import com.tmk.vtcmanager.application.domain.groupe.GroupeVehicule;
import com.tmk.vtcmanager.application.domain.vehicule.CreateVehiculeCommand;
import com.tmk.vtcmanager.application.domain.vehicule.UpdateVehiculeCommand;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.domain.vehicule.VehiculePhoto;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.request.UpdateVehiculeRequest;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.request.VehiculeRequest;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.GroupeSimpleResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.VehiculePhotoResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.VehiculeResponse;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring", uses = {TypeActiviteRestMapper.class, TypeVehiculeRestMapper.class, ModeleRestMapper.class, MarqueRestMapper.class})
public interface VehiculeRestMapper {

    @Mapping(target = "id", ignore = true)
    @Mapping(target = "groupe", ignore = true)
    @Mapping(target = "conditionTravail", ignore = true)
    @Mapping(target = "photos", ignore = true)
    @Mapping(target = "statutManuel", ignore = true)
    @Mapping(target = "prixAchat", ignore = true)
    @Mapping(target = "dureeAmortissementMois", ignore = true)
    @Mapping(target = "marque", source = "marqueId")
    @Mapping(target = "modele", source = "modeleId")
    @Mapping(target = "type", source = "typeVehiculeId")
    @Mapping(target = "activite", source = "typeActiviteId")
    Vehicule toDomain(VehiculeRequest request);

    CreateVehiculeCommand toCommand(VehiculeRequest request);

    @Mapping(target = "marqueId", ignore = true)
    @Mapping(target = "modeleId", ignore = true)
    @Mapping(target = "typeVehiculeId", ignore = true)
    UpdateVehiculeCommand toCommand(UpdateVehiculeRequest request);

    VehiculeResponse toResponse(Vehicule domain);

    List<VehiculeResponse> toResponseList(List<Vehicule> domains);

    VehiculePhotoResponse toPhotoResponse(VehiculePhoto photo);

    @Mapping(target = "typeActivite", source = "typeActivite")
    GroupeSimpleResponse toGroupeSimpleResponse(GroupeVehicule groupe);
}
