package com.tmk.vtcmanager.interfaces.rest.vehicule.dto.request;

import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatus;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;

import java.math.BigDecimal;
import java.time.LocalDate;

public record UpdateVehiculeRequest(
        String immatriculation,
        Long typeActiviteId,
        String numeroChassis,
        Long baliseId,
        String couleur,
        Integer kilometrage,
        VehiculeStatus statut,
        Long groupeId,
        Long conditionTravailId,
        LocalDate dateAchat,
        @PositiveOrZero BigDecimal prixAchat,
        @Positive Integer dureeAmortissementMois,
        LocalDate dateProchaineMaintenance,
        LocalDate dateMiseEnCirculation,
        LocalDate dateEntreeFlotte
) {}
