package com.tmk.vtcmanager.interfaces.rest.indisponibilite.dto.request;

import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;

public record IndisponibiliteRequest(
        @NotNull Long chauffeurId,
        @NotNull Long chauffeurRemplacantId,
        @NotNull LocalDate dateDebut,
        LocalDate dateFin,
        String motif,
        String commentaire
) {}
