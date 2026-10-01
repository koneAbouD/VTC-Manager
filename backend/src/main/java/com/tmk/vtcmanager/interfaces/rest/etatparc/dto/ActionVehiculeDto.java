package com.tmk.vtcmanager.interfaces.rest.etatparc.dto;

import java.time.LocalDate;

/**
 * Une action à mener sur un véhicule de la liste « demandant une action » :
 * son motif, l'échéance qui la qualifie et l'écran sur lequel l'ouvrir.
 * <p>
 * {@code finPrevue} est la fin de l'indisponibilité véhicule en cours (motif
 * {@code IMMOBILISATION_INDISPONIBILITE}, null si elle est ouverte).
 * {@code dateMaintenancePrevue} est l'échéance de la maintenance planifiée la plus
 * proche (motif {@code MAINTENANCE_PREVUE}). {@code dateProchaineVidange} et
 * {@code kmRestantVidange} ne sont renseignés que pour le motif {@code VIDANGE_DUE},
 * et seulement si la dernière vidange porte la cible correspondante.
 * <p>
 * {@code cible} dit vers quel écran ouvrir l'action — {@code MAINTENANCE},
 * {@code INDISPONIBILITE_VEHICULE}, {@code PENALITE}, {@code VIDANGE} ou
 * {@code VEHICULE} — et {@code cibleId} identifie l'objet visé quand il en existe
 * un. Une vidange due déjà planifiée en maintenance ouvre sur cette maintenance.
 */
public record ActionVehiculeDto(
        String motif,
        LocalDate finPrevue,
        LocalDate dateMaintenancePrevue,
        LocalDate dateProchaineVidange,
        Integer kmRestantVidange,
        String cible,
        Long cibleId
) {}
