package com.tmk.vtcmanager.application.domain.vehicule;

import java.math.BigDecimal;
import java.time.LocalDate;

public record UpdateVehiculeCommand(
        String immatriculation,
        Long marqueId,
        Long modeleId,
        Long typeVehiculeId,
        Long typeActiviteId,
        String numeroChassis,
        Long baliseId,
        String couleur,
        Integer kilometrage,
        VehiculeStatus statut,
        Long groupeId,
        Long conditionTravailId,
        LocalDate dateAchat,
        BigDecimal prixAchat,
        Integer dureeAmortissementMois,
        LocalDate dateProchaineMaintenance,
        LocalDate dateMiseEnCirculation,
        LocalDate dateEntreeFlotte
) {}