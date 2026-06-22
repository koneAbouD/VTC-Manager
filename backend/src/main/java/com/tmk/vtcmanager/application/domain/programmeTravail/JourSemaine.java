package com.tmk.vtcmanager.application.domain.programmeTravail;

import java.time.DayOfWeek;

public enum JourSemaine {
    LUNDI,
    MARDI,
    MERCREDI,
    JEUDI,
    VENDREDI,
    SAMEDI,
    DIMANCHE;

    public static JourSemaine from(DayOfWeek dayOfWeek) {
        return switch (dayOfWeek) {
            case MONDAY    -> LUNDI;
            case TUESDAY   -> MARDI;
            case WEDNESDAY -> MERCREDI;
            case THURSDAY  -> JEUDI;
            case FRIDAY    -> VENDREDI;
            case SATURDAY  -> SAMEDI;
            case SUNDAY    -> DIMANCHE;
        };
    }
}
