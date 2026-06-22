package com.tmk.vtcmanager.application.domain.conditionTravail;

public enum TypeSanction {

    BUZZER("Sonner le buzzer", ParamType.DUREE_SECONDES),
    AMENDE("Infliger une amende", ParamType.MONTANT),
    AVERTISSEMENT("Émettre un avertissement", ParamType.NONE),
    IMMOBILISATION("Immobiliser le véhicule", ParamType.DUREE_MINUTES);

    public final String label;
    public final ParamType paramType;

    TypeSanction(String label, ParamType paramType) {
        this.label = label;
        this.paramType = paramType;
    }

    public enum ParamType {
        DUREE_SECONDES,
        DUREE_MINUTES,
        MONTANT,
        NONE
    }
}
