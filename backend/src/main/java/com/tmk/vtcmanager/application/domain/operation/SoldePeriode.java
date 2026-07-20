package com.tmk.vtcmanager.application.domain.operation;

import java.math.BigDecimal;

/**
 * Agrégat de la carte solde de l'écran d'accueil sur une période :
 * total des revenus, total des dépenses (opérations annulées exclues) et solde
 * net. Reproduit côté serveur le calcul jusqu'ici fait dans le mobile.
 */
public record SoldePeriode(BigDecimal revenus, BigDecimal depenses) {

    public SoldePeriode {
        revenus = revenus == null ? BigDecimal.ZERO : revenus;
        depenses = depenses == null ? BigDecimal.ZERO : depenses;
    }

    /** Solde net de la période : revenus − dépenses. */
    public BigDecimal solde() {
        return revenus.subtract(depenses);
    }
}
