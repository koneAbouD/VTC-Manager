package com.tmk.vtcmanager.application.domain.finance;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * Marge sur coûts variables d'un véhicule (base caisse) : le comparateur
 * de flotte — n'impute pas arbitrairement les charges fixes.
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
    /** Nombre de jours d'immobilisation (indisponibilité véhicule) sur la période. */
    private long joursImmobilisation;
}
