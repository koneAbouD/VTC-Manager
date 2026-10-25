package com.tmk.vtcmanager.application.usecases.recette;

import com.tmk.vtcmanager.application.domain.recette.ResultatGenerationJournee;
import com.tmk.vtcmanager.application.usecases.cotisation.GenererLignesCotisationUseCase;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import java.time.LocalDate;

/**
 * Génère d'un seul geste les recettes et les cotisations d'une journée.
 *
 * <p>Simple composition : chaque génération garde ses propres règles — jour de
 * salaire sauté, alternance automatique, substitution des indisponibles,
 * véhicule immobilisé, purge des chauffeurs qui ne roulent plus ce jour,
 * garde-fou anti-doublon. Rien n'est recalculé ici, l'idempotence reste donc
 * celle des deux use cases.
 *
 * <p><b>Sans transaction englobante, volontairement.</b> Chaque génération
 * garde la sienne, ouverte par son bean : une cotisation mal configurée ne doit
 * pas annuler les recettes du jour, et inversement. Le bilan dit ce qui est
 * passé de chaque côté.
 */
@Slf4j
@RequiredArgsConstructor
public class GenererRecettesEtCotisationsUseCase {

    private final GenererLignesRecetteUseCase genererLignesRecetteUseCase;
    private final GenererLignesCotisationUseCase genererLignesCotisationUseCase;

    public ResultatGenerationJournee executer(LocalDate date) {
        int recettes = 0;
        String erreurRecettes = null;
        try {
            recettes = genererLignesRecetteUseCase.executer(date).size();
        } catch (RuntimeException e) {
            log.warn("Génération des recettes du {} non aboutie : {}", date, e.toString());
            erreurRecettes = messageLisible(e, "Génération des recettes impossible.");
        }

        int cotisations = 0;
        String erreurCotisations = null;
        try {
            cotisations = genererLignesCotisationUseCase.executer(date).size();
        } catch (RuntimeException e) {
            log.warn("Génération des cotisations du {} non aboutie : {}", date, e.toString());
            erreurCotisations = messageLisible(e, "Génération des cotisations impossible.");
        }

        return new ResultatGenerationJournee(date, recettes, erreurRecettes, cotisations, erreurCotisations);
    }

    private static String messageLisible(RuntimeException e, String parDefaut) {
        String message = e.getMessage();
        return (message == null || message.isBlank()) ? parDefaut : message;
    }
}
