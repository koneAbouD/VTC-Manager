package com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response;

import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatus;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public record VehiculeResponse(
        Long id,
        /** Jeton de version à renvoyer avec une modification. */
        Long version,
        String immatriculation,
        MarqueResponse marque,
        ModeleResponse modele,
        String numeroChassis,
        BaliseResponse balise,
        String couleur,
        Integer kilometrage,
        VehiculeStatus statut,
        TypeVehiculeResponse type,
        TypeActiviteResponse activite,
        GroupeSimpleResponse groupe,
        LocalDate dateAchat,
        BigDecimal prixAchat,
        Integer dureeAmortissementMois,
        LocalDate dateProchaineMaintenance,
        LocalDate dateMiseEnCirculation,
        LocalDate dateEntreeFlotte,
        List<VehiculePhotoResponse> photos
) {}
