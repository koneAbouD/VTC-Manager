package com.tmk.vtcmanager.interfaces.rest.chauffeur.mapper;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.chauffeur.Geolocalisation;
import com.tmk.vtcmanager.interfaces.rest.chauffeur.dto.request.ChauffeurRequest;
import com.tmk.vtcmanager.interfaces.rest.chauffeur.dto.response.ChauffeurResponse;
import com.tmk.vtcmanager.interfaces.rest.chauffeur.dto.response.GeolocalisationResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.mapper.VehiculeRestMapper;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring", uses = {VehiculeRestMapper.class})
public interface ChauffeurRestMapper {

    @Mapping(target = "id", ignore = true)
    @Mapping(target = "vehicule", ignore = true)
    @Mapping(target = "geolocalisation", ignore = true)
    @Mapping(target = "photoUrl", ignore = true)
    @Mapping(target = "photoPresignedUrl", ignore = true)
    @Mapping(target = "statutManuel", ignore = true)
    @Mapping(target = "dateSuspension", ignore = true)
    Chauffeur toDomain(ChauffeurRequest request);

    @Mapping(target = "documents", expression = "java(java.util.List.of())")
    @Mapping(target = "photoUrl", source = "photoPresignedUrl")
    ChauffeurResponse toResponse(Chauffeur domain);

    List<ChauffeurResponse> toResponseList(List<Chauffeur> domains);

    GeolocalisationResponse toGeolocalisationResponse(Geolocalisation geolocalisation);
}
