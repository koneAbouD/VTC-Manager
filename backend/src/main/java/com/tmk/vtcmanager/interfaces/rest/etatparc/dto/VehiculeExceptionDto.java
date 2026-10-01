package com.tmk.vtcmanager.interfaces.rest.etatparc.dto;

import java.time.LocalDate;
import java.util.List;

/**
 * Véhicule demandant une action — une seule ligne par véhicule, quel que soit le
 * nombre d'actions qu'il appelle (statut improductif, maintenance prévue, vidange
 * due). {@code actions} les liste toutes, la plus prioritaire en tête :
 * l'arrêt de production (immobilisation, maintenance en cours, sans chauffeur),
 * puis la maintenance prévue, puis la vidange due.
 * <p>
 * {@code joursDansStatut} est l'ancienneté dans le statut quand le véhicule est
 * listé au titre de son statut (null sinon). Les champs {@code motif} à
 * {@code cibleId} recopient l'action principale ({@code actions[0]}) : ils sont
 * conservés pour les clients qui ne lisent pas encore {@code actions}.
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
        Long cibleId,
        List<ActionVehiculeDto> actions
) {}
