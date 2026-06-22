package com.tmk.vtcmanager.interfaces.rest.vehicule.dto.request;

import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatus;

import java.time.LocalDate;

public record UpdateVehiculeRequest(
        String immatriculation,
        Long typeActiviteId,
        String numeroChassis,
        String numeroTelephoneVehicule,
        String numeroTelephoneBalise,
        String identifiantBalise,
        String couleur,
        Integer kilometrage,
        VehiculeStatus statut,
        Long groupeId,
        Long conditionTravailId,
        LocalDate dateAchat,
        LocalDate dateProchaineMaintenance,
        LocalDate dateMiseEnCirculation,
        LocalDate dateEntreeFlotte
) {}
