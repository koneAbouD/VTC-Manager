package com.tmk.vtcmanager.application.domain.vehicule;

import java.math.BigDecimal;
import java.time.LocalDate;

public record CreateVehiculeCommand(
        String immatriculation,
        Long marqueId,
        Long modeleId,
        Long typeVehiculeId,
        Long typeActiviteId,
        Long groupeId,
        String numeroChassis,
        Long baliseId,
        String couleur,
        Integer kilometrage,
        VehiculeStatus statut,
        LocalDate dateAchat,
        BigDecimal prixAchat,
        Integer dureeAmortissementMois,
        LocalDate dateProchaineMaintenance,
        LocalDate dateMiseEnCirculation,
        LocalDate dateEntreeFlotte
) {}
