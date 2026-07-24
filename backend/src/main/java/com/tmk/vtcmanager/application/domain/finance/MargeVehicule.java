package com.tmk.vtcmanager.application.domain.finance;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * Marge d'un véhicule (base caisse) : produits − charges variables (marge sur
 * coûts variables, le comparateur de flotte qui n'impute pas arbitrairement les
 * charges fixes) puis, après déduction de la dotation d'amortissement propre au
 * véhicule (prix d'achat / durée), la marge nette — mesure de rentabilité qui
 * tient compte du coût d'usure de l'immobilisation.
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
    /** Dotation d'amortissement du véhicule sur la période (0 si pas de prix d'achat). */
    private BigDecimal dotationAmortissement;
    /** Marge nette = marge sur coûts variables − dotation d'amortissement. */
    private BigDecimal margeNette;
    /** Nombre de jours d'immobilisation (indisponibilité véhicule) sur la période. */
    private long joursImmobilisation;
}
