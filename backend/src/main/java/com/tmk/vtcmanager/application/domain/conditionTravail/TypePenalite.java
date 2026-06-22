package com.tmk.vtcmanager.application.domain.conditionTravail;

public enum TypePenalite {

    RECETTE_NON_VERSEE("Recette non versée"),
    HEURE_FIN_SERVICE_PASSE("Heure de fin de service passée"),
    EXCES_VITESSE("Excès de vitesse");

    public final String label;

    TypePenalite(String label) {
        this.label = label;
    }
}
