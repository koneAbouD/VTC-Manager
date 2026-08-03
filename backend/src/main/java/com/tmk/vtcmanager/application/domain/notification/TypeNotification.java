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

    /** Envoi de vérification, déclenché manuellement depuis l'application. */
    TEST
}
