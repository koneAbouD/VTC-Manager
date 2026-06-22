package com.tmk.vtcmanager.interfaces.rest.groupe.dto;

import java.time.LocalDate;

public record GestionnaireGroupeResponse(
        Long id,
        String userId,
        String username,
        LocalDate dateDebut,
        LocalDate dateFin
) {}