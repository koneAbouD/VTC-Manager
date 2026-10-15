package com.tmk.vtcmanager.application.domain.reaffectation;

import java.math.BigDecimal;

/**
 * Ce que la réaffectation entraînerait, en faits chiffrés plutôt qu'en phrases.
 *
 * <p>L'écran de confirmation ne demande pas « êtes-vous sûr ? » — question à
 * laquelle personne ne sait répondre — il énonce ce qui va se passer. Encore
 * faut-il que ce soit vrai : sans ces nombres, le client annonçait qu'une
 * pénalité allait basculer même quand il n'y en avait aucune.
 *
 * <p>Des faits, et non des textes tout faits : la phrase se compose côté écran,
 * là où le nom du chauffeur choisi et le format des montants sont connus.
 *
 * <p>Les cotisations liées — dues par le même chauffeur, sur le même véhicule,
 * le même jour — ne concernent qu'une recette : l'écran propose de les emmener,
 * ou dit pourquoi elles ne peuvent pas suivre.
 */
public record ImpactsReaffectation(BigDecimal montantCreance,
                                   int encaissementsRattaches,
                                   BigDecimal montantEncaisse,
                                   int penalitesQuiSuivent,
                                   BigDecimal montantPenalites,
                                   int cotisationsLiees,
                                   BigDecimal montantCotisationsLiees,
                                   String motifCotisationsNonReaffectables) {

    /**
     * Sans cotisation à emmener : le cas d'une cotisation réaffectée pour
     * elle-même, ou d'une recette dont le chauffeur ne devait rien d'autre.
     */
    public ImpactsReaffectation(BigDecimal montantCreance, int encaissementsRattaches,
                                BigDecimal montantEncaisse, int penalitesQuiSuivent,
                                BigDecimal montantPenalites) {
        this(montantCreance, encaissementsRattaches, montantEncaisse, penalitesQuiSuivent,
                montantPenalites, 0, BigDecimal.ZERO, null);
    }
}
