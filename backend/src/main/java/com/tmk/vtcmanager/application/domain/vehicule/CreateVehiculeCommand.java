package com.tmk.vtcmanager.application.domain.vehicule;

import java.time.LocalDate;

public record CreateVehiculeCommand(
        String immatriculation,
        Long marqueId,
        Long modeleId,
        Long typeVehiculeId,
        Long typeActiviteId,
        Long groupeId,
        String numeroChassis,
        String numeroTelephoneVehicule,
        String numeroTelephoneBalise,
        String identifiantBalise,
        String couleur,
        Integer kilometrage,
        VehiculeStatus statut,
        LocalDate dateAchat,
        LocalDate dateProchaineMaintenance,
        LocalDate dateMiseEnCirculation,
        LocalDate dateEntreeFlotte
) {}
