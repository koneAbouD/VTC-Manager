package com.tmk.vtcmanager.interfaces.rest.tableaubord.dto;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Les quatre montants de la journée, posés en tête du tableau de bord à côté
 * de leur total mensuel. Lus par la même cascade que le compte de résultat,
 * restreinte à un jour, et dans la même base que le reste de l'écran.
 */
public record JourneeDto(
        /** Aujourd'hui pour le mois en cours, sinon le dernier jour de la période. */
        LocalDate date,
        /** Produits réellement versés ce jour-là, arriérés rattrapés compris. */
        BigDecimal encaisse,
        /**
         * Reste dû, à l'instant, sur les recettes et amendes de la veille —
         * celles qu'on encaisse ce jour-là. Jamais négatif.
         */
        BigDecimal manquant,
        /** Charges variables et fixes du jour, hors amortissements. */
        BigDecimal depenses,
        /**
         * Résultat du jour : produits − dépenses − quote-part d'amortissement. Sans
         * dotation aux provisions, qui ne se mesure qu'au mois.
         */
        BigDecimal beneficeNet
) {}
