package com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response;

import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatus;
import com.tmk.vtcmanager.interfaces.rest.document.dto.DocumentResponse;

import java.time.LocalDate;
import java.util.List;

public record VehiculeDetailResponse(
        Long id,
        String immatriculation,
        MarqueResponse marque,
        ModeleResponse modele,
        String numeroChassis,
        String numeroTelephoneBalise,
        String identifiantBalise,
        String couleur,
        Integer kilometrage,
        VehiculeStatus statut,
        TypeVehiculeResponse type,
        TypeActiviteResponse activite,
        GroupeSimpleResponse groupe,
        LocalDate dateAchat,
        LocalDate dateProchaineMaintenance,
        LocalDate dateMiseEnCirculation,
        LocalDate dateEntreeFlotte,
        List<VehiculePhotoResponse> photos,
        List<DocumentResponse> documents
) {}
