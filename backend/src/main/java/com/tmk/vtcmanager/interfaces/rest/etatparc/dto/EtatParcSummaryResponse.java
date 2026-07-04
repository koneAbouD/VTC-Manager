package com.tmk.vtcmanager.interfaces.rest.etatparc.dto;

import java.math.BigDecimal;
import java.util.List;

/**
 * Photo du parc à l'instant T.
 * <p>
 * Le parc actif exclut les véhicules HORS_PARC : les taux sont calculés sur ce
 * dénominateur pour ne pas être faussés par les véhicules sortis de la flotte.
 */
public record EtatParcSummaryResponse(
        // Compteurs
        int totalVehicules,
        int parcActif,
        int enService,
        int disponibles,
        int enMaintenance,
        int immobilises,
        int horsParc,

        // Taux (en %, sur le parc actif)
        BigDecimal tauxDisponibilite,
        BigDecimal tauxUtilisation,

        // Véhicules demandant une action, triés par ancienneté décroissante
        List<VehiculeExceptionDto> exceptions,

        EtatParcAlertesDto alertes
) {}
