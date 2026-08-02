package com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response;

import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatus;
import com.tmk.vtcmanager.interfaces.rest.document.dto.DocumentResponse;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public record VehiculeDetailResponse(
        Long id,
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
        /** Override du véhicule, {@code null} s'il suit la durée globale. */
        Integer dureeAmortissementMois,
        /** Durée réellement appliquée : override, sinon paramètre global, sinon 60. */
        Integer dureeAmortissementEffective,
        /**
         * Valeur nette comptable à aujourd'hui, calculée sur le même plan que
         * l'actif du bilan. {@code null} si le véhicule n'est pas amortissable
         * (prix d'achat absent) ou si son plan n'a pas commencé.
         */
        BigDecimal valeurNetteComptable,
        LocalDate dateProchaineMaintenance,
        LocalDate dateMiseEnCirculation,
        LocalDate dateEntreeFlotte,
        List<VehiculePhotoResponse> photos,
        List<DocumentResponse> documents
) {}
