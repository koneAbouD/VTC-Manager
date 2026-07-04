package com.tmk.vtcmanager.application.domain.finance;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * Compte de résultat de gestion en cascade (soldes intermédiaires
 * simplifiés). Base CAISSE : flux encaissés/payés de la période.
 * Base ENGAGEMENT : produits = montants dus de la période (date métier),
 * indépendamment de leur encaissement.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CompteResultat {

    private int annee;
    private int mois;
    private BaseComptable base;

    private BigDecimal produitsExploitation;
    private BigDecimal chargesVariables;
    /** produitsExploitation − chargesVariables. */
    private BigDecimal margeSurCoutsVariables;
    private BigDecimal chargesFixes;
    /** margeSurCoutsVariables − chargesFixes. */
    private BigDecimal excedentBrutExploitation;
    /** Dotation linéaire des véhicules amortissables sur la période. */
    private BigDecimal amortissements;
    /** excedentBrutExploitation − amortissements. */
    private BigDecimal resultatGestion;

    /** produits ENGAGEMENT − produits CAISSE : la variation des créances. */
    private BigDecimal pontCreances;

    public enum BaseComptable { CAISSE, ENGAGEMENT }
}
