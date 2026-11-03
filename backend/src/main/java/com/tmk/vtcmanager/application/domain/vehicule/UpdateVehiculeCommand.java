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
        /** Vrai = retirer la durée propre au véhicule, il reprend la durée globale.
         *  Un {@code null} sur la durée ne suffit pas : il veut dire « inchangée ». */
        Boolean dureeAmortissementParDefaut,
        LocalDate dateProchaineMaintenance,
        LocalDate dateMiseEnCirculation,
        LocalDate dateEntreeFlotte,
        /** Version de la fiche à partir de laquelle la modification a été
         *  saisie ; {@code null} = pas de contrôle (anciennes applications). */
        Long version
) {}