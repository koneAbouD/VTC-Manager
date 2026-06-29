package com.tmk.vtcmanager.interfaces.rest.indisponibilite.dto.response;

import com.tmk.vtcmanager.application.domain.indisponibilite.IndisponibiliteStatut;
import com.tmk.vtcmanager.interfaces.rest.chauffeur.dto.response.ChauffeurResponse;

import java.time.LocalDate;

public record IndisponibiliteResponse(
        Long id,
        ChauffeurResponse chauffeur,
        ChauffeurResponse chauffeurRemplacant,
        LocalDate dateDebut,
        LocalDate dateFin,
        String motif,
        String commentaire,
        IndisponibiliteStatut statut
) {}
