package com.tmk.vtcmanager.application.domain.tresorerie;

/**
 * Sort d'un écart de caisse constaté.
 *
 * <p>Tant qu'il est {@link #EN_ATTENTE}, l'écart dort en compte d'attente et ne
 * touche pas le résultat. L'imputation tranche : l'entreprise supporte la perte
 * (ou encaisse l'excédent), ou bien la somme est recouvrée auprès du
 * responsable.
 */
public enum StatutImputationEcart {
    EN_ATTENTE,
    /** Passé en charge (manquant) ou en produit (excédent). */
    PERTE,
    /** Remboursé par le responsable : le compte d'attente est soldé par sa recette. */
    RECOUVREE
}
