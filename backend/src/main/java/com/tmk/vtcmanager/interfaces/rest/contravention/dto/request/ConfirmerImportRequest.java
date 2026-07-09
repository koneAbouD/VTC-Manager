package com.tmk.vtcmanager.interfaces.rest.contravention.dto.request;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;

import java.util.List;

/**
 * Requête de confirmation d'import : les contraventions retenues et éventuellement
 * ajustées (chauffeur) par l'exploitant.
 */
public record ConfirmerImportRequest(
        @NotEmpty @Valid List<ContraventionImportItem> contraventions
) {}
