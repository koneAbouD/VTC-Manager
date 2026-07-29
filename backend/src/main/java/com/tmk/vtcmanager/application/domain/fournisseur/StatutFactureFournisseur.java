package com.tmk.vtcmanager.application.domain.fournisseur;

/** Où en est le règlement d'une facture reçue. */
public enum StatutFactureFournisseur {
    A_PAYER,
    PARTIELLEMENT_PAYEE,
    PAYEE,
    /** Facture reçue à tort, ou avoir total : elle ne porte plus de charge. */
    ANNULEE;

    /** Vrai tant que la facture pèse encore sur la dette. */
    public boolean estOuverte() {
        return this == A_PAYER || this == PARTIELLEMENT_PAYEE;
    }
}
