package com.tmk.vtcmanager.interfaces.rest.vehicule.dto.request;

import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatus;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;

public record VehiculeRequest(
        @NotBlank String immatriculation,
        @NotNull Long marqueId,
        @NotNull Long modeleId,
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
