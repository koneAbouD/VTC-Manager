package com.tmk.vtcmanager.interfaces.rest.recette.dto.response;

import java.time.LocalDate;

/**
 * Bilan de la génération recettes + cotisations d'une journée. Les deux côtés
 * étant indépendants, la réponse est toujours un 201 : c'est le détail qui dit
 * ce qui est passé et ce qui a été refusé, avec le motif à afficher tel quel.
 */
public record GenerationJourneeResponse(
        LocalDate date,
        int recettes,
        String erreurRecettes,
        int cotisations,
        String erreurCotisations
) {}
