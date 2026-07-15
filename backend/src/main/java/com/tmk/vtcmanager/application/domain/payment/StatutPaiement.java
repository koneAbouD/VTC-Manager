package com.tmk.vtcmanager.application.domain.payment;

/** Machine à états d'un paiement Mobile Money. */
public enum StatutPaiement {
    /** Créé localement, avant appel à l'agrégateur. */
    INITIE,
    /** Transmis à l'agrégateur, en attente de confirmation du payeur. */
    EN_ATTENTE,
    /** Confirmé : les fonds sont partis vers le compte marchand. */
    REUSSI,
    /** Refusé / annulé par le payeur ou l'agrégateur. */
    ECHOUE,
    /** Expiré sans confirmation. */
    EXPIRE;

    public boolean estTerminal() {
        return this == REUSSI || this == ECHOUE || this == EXPIRE;
    }
}
