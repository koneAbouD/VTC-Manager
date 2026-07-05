package com.tmk.vtcmanager.application.domain.vehicule;

/**
 * Motif d'entrée dans un statut, historisé avec la transition. Permet à l'état
 * de parc de distinguer une immobilisation subie (panne) d'une immobilisation
 * administrative (pénalité) ou d'une simple absence d'affectation.
 */
public enum VehiculeStatutMotif {
    /** Immobilisation liée à une pénalité active (calculée). */
    IMMOBILISATION_PENALITE,
    /** Immobilisation planifiée hors atelier (accident/sinistre, panne, administratif). */
    IMMOBILISATION_INDISPONIBILITE,
    /** Immobilisation décidée manuellement (panne, accident, saisie). */
    PANNE_OU_ACCIDENT,
    /** Au moins une maintenance EN_COURS. */
    MAINTENANCE_EN_COURS,
    /** Un chauffeur est affecté au véhicule. */
    CHAUFFEUR_AFFECTE,
    /** Aucun chauffeur affecté : le véhicule ne produit pas. */
    SANS_CHAUFFEUR,
    /** Sortie du parc décidée manuellement (vente, réforme, restitution). */
    SORTIE_PARC,
    /** Statut posé manuellement sans verrou (retour au calcul ensuite). */
    DECISION_MANUELLE,
    /** Première entrée du véhicule dans la flotte. */
    ENTREE_FLOTTE
}
