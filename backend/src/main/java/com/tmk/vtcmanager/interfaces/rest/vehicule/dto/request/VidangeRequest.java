package com.tmk.vtcmanager.interfaces.rest.vehicule.dto.request;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;

import java.time.LocalDate;

public record VidangeRequest(
        @NotNull(message = "La date de la vidange est obligatoire.")
        LocalDate dateVidange,

        @NotNull(message = "Le kilométrage de la vidange est obligatoire.")
        @PositiveOrZero(message = "Le kilométrage de la vidange doit être positif.")
        Integer kilometrageVidange,

        LocalDate dateProchaineVidange,

        @PositiveOrZero(message = "Le kilométrage de la prochaine vidange doit être positif.")
        Integer kilometrageProchaineVidange,

        String commentaire
) {}
