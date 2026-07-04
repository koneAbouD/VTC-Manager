package com.tmk.vtcmanager.application.domain.operation;

/**
 * Classification d'une catégorie pour le compte de résultat (cascade V2).
 * HORS_RESULTAT = comptes de tiers (contraventions refacturées, transferts) :
 * exclus des agrégats revenus/dépenses pour ne pas gonfler le résultat.
 */
public enum NatureResultat {
    PRODUIT_EXPLOITATION,
    CHARGE_VARIABLE,
    CHARGE_FIXE,
    HORS_RESULTAT
}
