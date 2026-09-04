package com.tmk.vtcmanager.interfaces.rest.tableaubord.dto;

import java.math.BigDecimal;
import java.util.List;

/**
 * Bloc « est-ce que l'argent rentre » : un résultat positif dont les produits
 * dorment en créances ne paie ni le carburant ni les salaires. On y lit donc
 * la trésorerie réellement disponible, ce qui reste dû, et la vitesse à
 * laquelle cela rentre.
 * <p>
 * Le {@code dso} (<i>days sales outstanding</i>) est le nombre de jours de
 * production que représente l'encours : créances / produits journaliers. Il se
 * compare au rythme de versement attendu des chauffeurs — au-delà, l'encours
 * n'est plus un décalage, c'est un impayé.
 */
public record CashCreancesDto(
        /** Somme des soldes des comptes de trésorerie actifs. */
        BigDecimal tresorerieDisponible,

        BigDecimal creancesBrutes,
        BigDecimal creances0a7Jours,
        BigDecimal creances8a30Jours,
        BigDecimal creancesPlus30Jours,
        /** Part de l'encours à plus de 30 jours, en % : la fraction qui vieillit mal. */
        BigDecimal partCreancesRisque,

        BigDecimal provisionCreances,
        BigDecimal creancesNettes,

        /** Produits encaissés / produits dus de la période, en %. Null si rien n'était dû. */
        BigDecimal tauxRecouvrement,
        /** Produits dus non encore encaissés sur la période (le pont créances). */
        BigDecimal resteAEncaisserPeriode,
        /** Jours de production que représente l'encours. Null si aucun produit sur la période. */
        BigDecimal dso,

        /** Contraventions encaissées auprès des chauffeurs et pas encore reversées. */
        BigDecimal aReverserEtat,

        int nbChauffeursDebiteurs,
        /** Les cinq encours les plus lourds, du plus élevé au plus faible. */
        List<DebiteurDto> topDebiteurs
) {}
