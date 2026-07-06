package com.tmk.vtcmanager.interfaces.rest.etatparc.dto;

/** Alertes préventives : ce qui risque d'immobiliser le parc prochainement. */
public record EtatParcAlertesDto(
        int documentsExpirantSous30Jours,
        int maintenancesDuesSous7Jours,
        int permisExpires,
        /** Vidanges dues : date prévue proche (≤ 7 j) ou kilométrage cible presque atteint. */
        int vidangesDues
) {}
