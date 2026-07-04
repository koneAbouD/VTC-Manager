package com.tmk.vtcmanager.application.domain.tresorerie;

import com.tmk.vtcmanager.application.domain.operation.ModePaiement;

public enum TypeCompteTresorerie {
    CAISSE,
    MOBILE_MONEY,
    BANQUE;

    /**
     * Type de compte attendu pour un mode de paiement : sert à résoudre le
     * compte par défaut quand l'opération ne précise pas de compte.
     */
    public static TypeCompteTresorerie pourModePaiement(ModePaiement mode) {
        return mode == ModePaiement.MOBILE_MONEY ? MOBILE_MONEY : CAISSE;
    }
}
