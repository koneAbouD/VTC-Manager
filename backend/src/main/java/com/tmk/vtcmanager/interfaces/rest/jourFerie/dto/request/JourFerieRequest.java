package com.tmk.vtcmanager.interfaces.rest.jourFerie.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;

/** Ajout/confirmation manuelle d'un jour férié (fêtes musulmanes, décrets). */
public record JourFerieRequest(

        @NotNull
        LocalDate date,

        @NotBlank
        String libelle,

        // FIXE | CHRETIEN | MUSULMAN | AUTRE — défaut MUSULMAN si absent
        String type

) {}
