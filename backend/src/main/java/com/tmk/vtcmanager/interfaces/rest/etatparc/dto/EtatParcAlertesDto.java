package com.tmk.vtcmanager.interfaces.rest.etatparc.dto;

/** Alertes préventives : ce qui risque d'immobiliser le parc prochainement. */
public record EtatParcAlertesDto(
        int documentsExpirantSous30Jours,
        /** Nombre de <b>véhicules</b> (et non de lignes) dont une maintenance planifiée
         *  est échue ou due sous 7 j. Nom de champ conservé pour la compatibilité des
         *  applications déjà installées. */
        int maintenancesDuesSous7Jours,
        int permisExpires,
        /** Vidanges dues : date prévue proche (≤ 7 j) ou kilométrage cible presque atteint. */
        int vidangesDues
) {}
