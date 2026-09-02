package com.tmk.vtcmanager.application.domain.notification;

/**
 * Nature métier d'une notification. Elle détermine l'icône et l'écran ouvert
 * côté mobile ; le texte, lui, est composé par le use case émetteur car il
 * dépend des données de l'événement.
 */
public enum TypeNotification {

    /** Une pénalité vient d'être portée au compte du chauffeur. */
    PENALITE_APPLIQUEE,

    /** Un versement de recette vient d'être porté au compte du chauffeur. */
    RECETTE_ENCAISSEE,

    /** Un versement de cotisation vient d'être porté au compte du chauffeur. */
    COTISATION_ENCAISSEE,

    /** L'arrêté de compte du chauffeur est disponible (prime à percevoir). */
    ARRETE_COMPTE_DISPONIBLE,

    /** Une maintenance planifiée approche de sa date prévue. */
    MAINTENANCE_A_VENIR,

    /**
     * Une créance a changé de débiteur : elle quitte le compte d'un chauffeur
     * pour celui d'un autre. Les deux sont prévenus — l'un est déchargé, l'autre
     * doit désormais la somme.
     */
    LIGNE_REAFFECTEE,

    /**
     * La génération quotidienne a produit des créances incohérentes : un
     * chauffeur se retrouve sur plusieurs véhicules le même jour. Rien n'a été
     * bloqué — une recette manquante coûte plus cher qu'une recette en trop —
     * mais l'exploitation doit trancher.
     */
    ANOMALIE_GENERATION,

    /** Envoi de vérification, déclenché manuellement depuis l'application. */
    TEST
}
