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

    /**
     * Nom du contrôle périodique attendu sur ce type de compte. Des espèces se
     * <em>comptent</em> ; un portefeuille mobile money se compare au
     * <em>relevé</em> de l'opérateur ; un compte bancaire se
     * <em>rapproche</em> de son relevé. Le mécanisme est le même — constater le
     * solde réel et traiter l'écart — mais le mot engage des diligences
     * différentes, et un « comptage » de banque n'aurait aucune valeur probante.
     */
    public String libelleControle() {
        return switch (this) {
            case CAISSE -> "comptage";
            case MOBILE_MONEY -> "relevé";
            case BANQUE -> "rapprochement bancaire";
        };
    }

    /** Verbe du contrôle, pour les messages adressés à l'utilisateur. */
    public String verbeControle() {
        return switch (this) {
            case CAISSE -> "comptez-le";
            case MOBILE_MONEY -> "relevez son solde";
            case BANQUE -> "rapprochez-le de son relevé";
        };
    }
}
