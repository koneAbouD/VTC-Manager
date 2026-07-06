package com.tmk.vtcmanager.application.domain.jourFerie;

/** Nature d'un jour férié, déterminant s'il est calculable automatiquement. */
public enum TypeJourFerie {
    /** Date civile fixe (ex. 7 août, 25 décembre). Calculable. */
    FIXE,
    /** Fête chrétienne mobile dérivée de Pâques (Lundi de Pâques, Ascension...). Calculable. */
    CHRETIEN,
    /** Fête musulmane (calendrier lunaire, fixée par décret). Saisie manuelle. */
    MUSULMAN,
    /** Autre jour férié ponctuel (décret exceptionnel). Saisie manuelle. */
    AUTRE
}
