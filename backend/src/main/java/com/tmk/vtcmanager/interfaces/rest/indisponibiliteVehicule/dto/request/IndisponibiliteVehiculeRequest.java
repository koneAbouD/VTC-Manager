package com.tmk.vtcmanager.interfaces.rest.indisponibiliteVehicule.dto.request;

import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;

public record IndisponibiliteVehiculeRequest(
        @NotNull Long vehiculeId,
        @NotNull LocalDate dateDebut,
        LocalDate dateFin,
        String motif,
        String commentaire
) {}
