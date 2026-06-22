package com.tmk.vtcmanager.interfaces.rest.groupe.dto;

import com.tmk.vtcmanager.application.domain.groupe.GroupeStatut;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.TypeActiviteResponse;

public record GroupeVehiculeResponse(
        Long id,
        String nom,
        String description,
        TypeActiviteResponse typeActivite,
        GroupeStatut statut,
        GestionnaireGroupeResponse gestionnaire,
        int nbVehicules
) {}