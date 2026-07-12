package com.tmk.vtcmanager.application.domain.cotisation;

public enum StatutLigneCotisation {
    EN_ATTENTE,
    PARTIELLEMENT_ENCAISSE,
    ENCAISSE,
    ANNULEE,
    /** Ligne prise en compte dans un arrêté de compte : dépôt rendu/netté, hors fonds restituable. */
    RESTITUEE
}
