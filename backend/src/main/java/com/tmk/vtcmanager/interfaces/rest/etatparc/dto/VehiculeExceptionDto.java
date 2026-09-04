package com.tmk.vtcmanager.interfaces.rest.etatparc.dto;

import java.time.LocalDate;

/**
 * Véhicule demandant une action : ne produit pas (immobilisé, en maintenance,
 * disponible sans chauffeur), avec le motif et l'ancienneté dans le statut.
 * {@code finPrevue} est la date de fin de l'indisponibilité véhicule en cours
 * (null si le motif n'est pas une immobilisation planifiée ou si elle est ouverte).
 * {@code dateMaintenancePrevue} est l'échéance de la maintenance planifiée la plus
 * proche (motif {@code MAINTENANCE_PREVUE}), null sinon. {@code dateProchaineVidange}
 * et {@code kmRestantVidange} ne sont renseignés que pour le motif
 * {@code VIDANGE_DUE}, et seulement si la dernière vidange porte la cible
 * correspondante (une vidange peut n'être due que par date, ou que par kilométrage).
 * <p>
 * {@code cible} dit vers quel écran ouvrir la ligne — {@code MAINTENANCE},
 * {@code INDISPONIBILITE_VEHICULE}, {@code PENALITE}, {@code VIDANGE} ou
 * {@code VEHICULE} — et {@code cibleId} identifie l'objet visé quand il en existe
 * un (null quand la cible se résout sur le véhicule lui-même).
 */
public record VehiculeExceptionDto(
        Long vehiculeId,
        String immatriculation,
        String libelleVehicule,
        String statut,
        String motif,
        Long joursDansStatut,
        LocalDate finPrevue,
        LocalDate dateMaintenancePrevue,
        LocalDate dateProchaineVidange,
        Integer kmRestantVidange,
        String cible,
        Long cibleId
) {}
