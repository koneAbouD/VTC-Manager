package com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response;

import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatus;

import java.time.LocalDate;
import java.util.List;

public record VehiculeResponse(
        Long id,
        String immatriculation,
        MarqueResponse marque,
        ModeleResponse modele,
        String numeroChassis,
        String numeroTelephoneVehicule,
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
        List<VehiculePhotoResponse> photos
) {}
