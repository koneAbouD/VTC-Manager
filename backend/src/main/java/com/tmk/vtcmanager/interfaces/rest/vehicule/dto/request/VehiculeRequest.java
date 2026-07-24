package com.tmk.vtcmanager.interfaces.rest.vehicule.dto.request;

import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatus;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;

import java.math.BigDecimal;
import java.time.LocalDate;

public record VehiculeRequest(
        @NotBlank String immatriculation,
        @NotNull Long marqueId,
        @NotNull Long modeleId,
        Long typeVehiculeId,
        Long typeActiviteId,
        Long groupeId,
        String numeroChassis,
        Long baliseId,
        String couleur,
        Integer kilometrage,
        VehiculeStatus statut,
        LocalDate dateAchat,
        @PositiveOrZero BigDecimal prixAchat,
        @Positive Integer dureeAmortissementMois,
        LocalDate dateProchaineMaintenance,
        LocalDate dateMiseEnCirculation,
        LocalDate dateEntreeFlotte
) {}
