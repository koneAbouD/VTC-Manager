package com.tmk.vtcmanager.application.domain.contravention;

/**
 * État du rattachement d'une contravention de l'État à un chauffeur, déduit du
 * programme de travail du véhicule à la date (et l'heure) de l'infraction.
 */
public enum StatutRattachement {

    /** Chauffeur déduit automatiquement (un seul conducteur programmé, sans ambiguïté). */
    AUTO,
    /** Chauffeur affecté manuellement par l'exploitant. */
    MANUEL,
    /** Aucun chauffeur déterminé (pas de programme, ou ambiguïté non résolue). */
    A_RATTACHER
}
