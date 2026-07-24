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
        Integer dureeAmortissementMois,
        LocalDate dateProchaineMaintenance,
        LocalDate dateMiseEnCirculation,
        LocalDate dateEntreeFlotte,
        List<VehiculePhotoResponse> photos,
        List<DocumentResponse> documents
) {}
