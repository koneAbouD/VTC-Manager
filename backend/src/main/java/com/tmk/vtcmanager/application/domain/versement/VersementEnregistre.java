package com.tmk.vtcmanager.application.domain.versement;

import java.util.List;
import java.util.UUID;

/**
 * Ce que le versement a produit.
 *
 * <p>{@code versementId} est nul quand il ne soldait qu'une créance : une
 * écriture seule n'a rien à rassembler, et ne doit pas s'afficher comme une
 * pièce de caisse.
 *
 * @param operationIds les écritures produites — ce qu'un reçu PDF atteste
 */
public record VersementEnregistre(
        UUID versementId,
        Long encaissementRecetteId,
        Long encaissementCotisationId,
        List<Long> operationIds
) {}
