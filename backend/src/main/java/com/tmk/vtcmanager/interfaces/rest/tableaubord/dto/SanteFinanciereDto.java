package com.tmk.vtcmanager.interfaces.rest.tableaubord.dto;

import java.math.BigDecimal;
import java.util.List;

/**
 * Bloc « est-ce que je gagne de l'argent » : la cascade du compte de résultat,
 * complétée des ratios de structure qu'un exploitant lit avant les montants.
 * <p>
 * Le {@code pointMort} est le chiffre d'affaires à partir duquel les charges
 * fixes sont couvertes ({@code chargesFixes / tauxMargeVariable}) : il dit, en
 * une valeur, combien il reste à produire pour ne plus perdre.
 */
public record SanteFinanciereDto(
        BigDecimal produits,
        BigDecimal chargesVariables,
        BigDecimal margeSurCoutsVariables,
        BigDecimal chargesFixes,
        BigDecimal excedentBrutExploitation,
        BigDecimal amortissements,
        BigDecimal dotationProvisions,
        BigDecimal resultatGestion,

        /** MCV / produits, en % : ce que chaque franc encaissé laisse après charges variables. */
        BigDecimal tauxMargeVariable,
        /** (charges variables + fixes) / produits, en %. */
        BigDecimal tauxCharges,
        /** Chiffre d'affaires couvrant tout juste les charges fixes. Null si la marge est nulle ou négative. */
        BigDecimal pointMort,
        /** produits / pointMort, en % : 100 % = équilibre atteint. Null quand le point mort l'est. */
        BigDecimal tauxCouverturePointMort,

        /** Variations en % par rapport au mois précédent complet. */
        BigDecimal variationProduitsPct,
        BigDecimal variationResultatPct,

        /** Douze derniers mois glissants, du plus ancien au plus récent. */
        List<PointSerieDto> serie
) {}
