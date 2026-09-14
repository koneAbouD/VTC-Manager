package com.tmk.vtcmanager.interfaces.rest.versement.dto.response;

import java.util.UUID;
import java.util.List;

/** Nul {@code versementId} : une seule créance était soldée, rien n'est rassemblé. */
public record VersementEnregistreResponse(
        UUID versementId,
        Long encaissementRecetteId,
        Long encaissementCotisationId,
        /** Écritures produites : ce qu'un reçu PDF atteste. */
        List<Long> operationIds
) {}
