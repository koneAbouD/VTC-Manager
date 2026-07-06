package com.tmk.vtcmanager.application.domain.jourFerie;

/** Origine d'un jour férié : calculé automatiquement ou saisi/confirmé à la main. */
public enum SourceJourFerie {
    /** Généré par le calculateur (fériés fixes et chrétiens). */
    AUTO,
    /** Saisi ou confirmé manuellement (fêtes musulmanes, décrets). */
    MANUEL
}
