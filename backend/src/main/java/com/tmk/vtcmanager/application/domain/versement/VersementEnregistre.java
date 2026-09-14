package com.tmk.vtcmanager.application.domain.versement;

import java.util.UUID;

/**
 * Ce que le versement a produit.
 *
 * <p>{@code versementId} est nul quand il ne soldait qu'une créance : une
 * écriture seule n'a rien à rassembler, et ne doit pas s'afficher comme une
 * pièce de caisse.
 */
public record VersementEnregistre(
        UUID versementId,
        Long encaissementRecetteId,
        Long encaissementCotisationId
) {}
