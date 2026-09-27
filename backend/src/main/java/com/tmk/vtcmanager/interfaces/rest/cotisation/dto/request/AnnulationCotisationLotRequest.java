package com.tmk.vtcmanager.interfaces.rest.cotisation.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;

/**
 * Cotisations d'une période à annuler d'un geste, sous un même motif. Borne
 * haute pour qu'une sélection malheureuse n'emporte pas des centaines de lignes.
 */
public record AnnulationCotisationLotRequest(
        @NotEmpty @Size(max = 200) List<@NotNull Long> ligneIds,
        @NotBlank String motif
) {}
