package com.tmk.vtcmanager.interfaces.rest.etatparc.dto;

import java.time.LocalDate;

/**
 * Véhicule demandant une action : ne produit pas (immobilisé, en maintenance,
 * disponible sans chauffeur), avec le motif et l'ancienneté dans le statut.
 * {@code finPrevue} est la date de fin de l'indisponibilité véhicule en cours
 * (null si le motif n'est pas une immobilisation planifiée ou si elle est ouverte).
 */
public record VehiculeExceptionDto(
        Long vehiculeId,
        String immatriculation,
        String libelleVehicule,
        String statut,
        String motif,
        Long joursDansStatut,
        LocalDate finPrevue
) {}
