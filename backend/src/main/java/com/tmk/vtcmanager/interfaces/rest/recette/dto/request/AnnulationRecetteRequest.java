package com.tmk.vtcmanager.interfaces.rest.recette.dto.request;

import jakarta.validation.constraints.NotBlank;

/**
 * Annulation d'une recette : motif obligatoire, et le choix d'emporter ou non
 * les cotisations de la même journée.
 *
 * <p>Champ absent = cascade refusée : un ancien client, qui ne connaît pas
 * l'option, n'annule que ce qu'il croit annuler.
 */
public record AnnulationRecetteRequest(
        @NotBlank(message = "Le motif d'annulation est obligatoire.") String motif,
        Boolean annulerCotisationsLiees
) {
    public boolean cascadeDemandee() {
        return Boolean.TRUE.equals(annulerCotisationsLiees);
    }
}
