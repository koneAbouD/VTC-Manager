package com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response;

import com.tmk.vtcmanager.application.domain.groupe.GroupeStatut;

public record GroupeSimpleResponse(
        Long id,
        String nom,
        String description,
        TypeActiviteResponse typeActivite,
        GroupeStatut statut
) {}