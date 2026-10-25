package com.tmk.vtcmanager.application.domain.recette;

import java.time.LocalDate;

/**
 * Bilan de la génération d'une journée : recettes et cotisations d'un même geste.
 *
 * <p>Les deux générations ne forment pas un tout ou rien : la cotisation est un
 * dépôt hors résultat, distinct de la recette, et l'échec de l'une ne doit pas
 * priver le guichet de l'autre. Chaque côté rend donc son nombre de lignes
 * (créées ou remises à jour) ou le motif de son refus, à afficher tel quel.
 */
public record ResultatGenerationJournee(
        LocalDate date,
        int recettes,
        String erreurRecettes,
        int cotisations,
        String erreurCotisations
) {

    public boolean recettesReussies() {
        return erreurRecettes == null;
    }

    public boolean cotisationsReussies() {
        return erreurCotisations == null;
    }
}
