package com.tmk.vtcmanager.application.domain.finance;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * Rentabilité d'un véhicule, en trois paliers qui vont du plus opérationnel au
 * plus complet :
 * <ol>
 *   <li>produits − charges variables : la marge sur coûts variables, ce que le
 *       véhicule dégage sur son seul roulage ;</li>
 *   <li>− charges directes : assurance, vignette, patente, visite technique —
 *       fixes dans le mois, mais payées <em>pour ce véhicule</em>. Les ignorer
 *       mettait au même rang un véhicule assuré et un véhicule qui n'avait rien
 *       coûté. Les charges de structure, elles, restent hors de ce calcul :
 *       aucune clé de répartition ne serait honnête ;</li>
 *   <li>− dotation d'amortissement (prix d'achat / durée) : la marge nette, qui
 *       tient compte du coût d'usure de l'immobilisation.</li>
 * </ol>
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MargeVehicule {

    private Long vehiculeId;
    private String immatriculation;
    private BigDecimal produits;
    private BigDecimal chargesVariables;
    private BigDecimal marge;
    /** Charges fixes payées pour ce véhicule (assurance, vignette, patente…). */
    private BigDecimal chargesDirectes;
    /** Marge sur coûts variables − charges directes. */
    private BigDecimal margeApresChargesDirectes;
    /** Dotation d'amortissement du véhicule sur la période (0 si pas de prix d'achat). */
    private BigDecimal dotationAmortissement;
    /** Marge nette = marge après charges directes − dotation d'amortissement. */
    private BigDecimal margeNette;
    /** Nombre de jours d'immobilisation (indisponibilité véhicule) sur la période. */
    private long joursImmobilisation;
}
