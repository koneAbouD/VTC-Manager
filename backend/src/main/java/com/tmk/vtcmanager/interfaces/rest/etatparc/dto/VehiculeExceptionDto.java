package com.tmk.vtcmanager.interfaces.rest.etatparc.dto;

/**
 * Véhicule demandant une action : ne produit pas (immobilisé, en maintenance,
 * disponible sans chauffeur), avec le motif et l'ancienneté dans le statut.
 */
public record VehiculeExceptionDto(
        Long vehiculeId,
        String immatriculation,
        String libelleVehicule,
        String statut,
        String motif,
        Long joursDansStatut
) {}
