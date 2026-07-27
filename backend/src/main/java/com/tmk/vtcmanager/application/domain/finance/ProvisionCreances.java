package com.tmk.vtcmanager.application.domain.finance;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * Dépréciation des créances chauffeurs, par tranche d'ancienneté.
 *
 * <p>Porter les créances au bilan pour leur valeur brute surévalue l'actif et le
 * résultat : plus une somme dort, moins elle rentre. La provision met l'actif à
 * sa valeur probable de recouvrement, et la dotation constate la perte
 * attendue.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ProvisionCreances {

    /** Créances brutes, telles qu'elles figurent dans la balance âgée. */
    private BigDecimal creancesBrutes;

    private BigDecimal base0a7Jours;
    private BigDecimal base8a30Jours;
    private BigDecimal basePlus30Jours;

    /** Taux appliqués, en pourcentage (paramétrables). */
    private BigDecimal taux0a7Jours;
    private BigDecimal taux8a30Jours;
    private BigDecimal tauxPlus30Jours;

    /** Provision calculée sur chaque tranche. */
    private BigDecimal provision0a7Jours;
    private BigDecimal provision8a30Jours;
    private BigDecimal provisionPlus30Jours;

    /** Somme des trois tranches. */
    private BigDecimal provisionTotale;

    /** creancesBrutes − provisionTotale : ce qu'on espère raisonnablement encaisser. */
    private BigDecimal creancesNettes;
}
