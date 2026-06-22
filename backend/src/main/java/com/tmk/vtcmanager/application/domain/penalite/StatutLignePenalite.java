package com.tmk.vtcmanager.application.domain.penalite;

public enum StatutLignePenalite {

    EN_ATTENTE,
    PARTIELLEMENT_ENCAISSEE,
    ENCAISSEE,
    EXECUTEE,
    NOTIFIEE,
    EN_COURS,
    LEVEE,
    ANNULEE;

    public boolean isTerminal() {
        return this == ENCAISSEE || this == EXECUTEE
                || this == NOTIFIEE || this == LEVEE
                || this == ANNULEE;
    }
}
