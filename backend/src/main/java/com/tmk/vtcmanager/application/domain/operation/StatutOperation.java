package com.tmk.vtcmanager.application.domain.operation;

public enum StatutOperation {
    ENCAISSE,
    PAYE,
    ANNULEE;

    /**
     * Statut "terminé" attendu selon le type d'opération :
     * un revenu est ENCAISSE, une dépense est PAYE.
     */
    public static StatutOperation termineePour(TypeOperation type) {
        return type == TypeOperation.REVENU ? ENCAISSE : PAYE;
    }

    /** Vrai si l'opération est dans un état terminal validé (encaissée/payée). */
    public boolean estTerminee() {
        return this == ENCAISSE || this == PAYE;
    }
}
