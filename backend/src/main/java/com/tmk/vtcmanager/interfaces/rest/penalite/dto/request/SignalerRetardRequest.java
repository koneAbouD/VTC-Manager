package com.tmk.vtcmanager.interfaces.rest.penalite.dto.request;

import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;

public record SignalerRetardRequest(
        @NotNull Long vehiculeId,
        @NotNull Long chauffeurId,
        @NotNull LocalDate dateFaute,
        String commentaire
) {}
