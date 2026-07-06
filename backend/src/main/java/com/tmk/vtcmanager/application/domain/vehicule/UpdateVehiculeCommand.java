package com.tmk.vtcmanager.application.domain.vehicule;

import java.time.LocalDate;

public record UpdateVehiculeCommand(
        String immatriculation,
        Long marqueId,
        Long modeleId,
        Long typeVehiculeId,
        Long typeActiviteId,
        String numeroChassis,
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