package com.tmk.vtcmanager.application.domain.contravention.reversement;

/**
 * Classement d'une ligne de quittance après rapprochement avec la base.
 */
public enum StatutLigneReversement {

    /** Contravention trouvée et non encore reversée : elle sera reversée. */
    A_REVERSER,

    /** Contravention déjà au statut REVERSE : ignorée (idempotence). */
    DEJA_REVERSEE,

    /** Aucune contravention en base ne porte ce numéro. */
    INTROUVABLE
}
