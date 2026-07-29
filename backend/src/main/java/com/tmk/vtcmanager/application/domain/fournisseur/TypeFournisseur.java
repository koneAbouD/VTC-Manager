package com.tmk.vtcmanager.application.domain.fournisseur;

/** Nature du fournisseur, pour regrouper les dettes par famille d'achat. */
public enum TypeFournisseur {
    GARAGE,
    PIECES,
    CARBURANT,
    ASSURANCE,
    /** État et régies : vignette, patente, taxes. */
    ADMINISTRATION,
    BAILLEUR,
    AUTRE
}
