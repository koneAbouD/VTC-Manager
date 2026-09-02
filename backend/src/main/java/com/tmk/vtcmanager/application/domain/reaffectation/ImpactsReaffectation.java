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
 */
public record ImpactsReaffectation(BigDecimal montantCreance,
                                   int encaissementsRattaches,
                                   BigDecimal montantEncaisse,
                                   int penalitesQuiSuivent,
                                   BigDecimal montantPenalites) {}
