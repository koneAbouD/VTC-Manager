package com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response;

import com.fasterxml.jackson.annotation.JsonFormat;
import com.tmk.vtcmanager.application.domain.chauffeur.ChauffeurStatus;
import com.tmk.vtcmanager.application.domain.chauffeur.TypeChauffeur;

import java.time.LocalDate;

public record ProgrammeChauffeurResponse(
        Long id,
        Long chauffeurId,
        String nom,
        String prenom,
        String nomComplet,
        String telephone,
        String photoUrl,
        TypeChauffeur type,
        ChauffeurStatus statut,
        Integer ordreAlternance,
        Integer ordreJourSalaire,
        @JsonFormat(pattern = "yyyy-MM-dd") LocalDate dateService
) {}
