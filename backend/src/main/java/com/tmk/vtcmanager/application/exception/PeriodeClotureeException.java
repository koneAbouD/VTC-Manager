package com.tmk.vtcmanager.application.exception;

import java.time.LocalDate;

public class PeriodeClotureeException extends RuntimeException {

    public PeriodeClotureeException(LocalDate date) {
        super("Impossible d'écrire au " + date + " : la période comptable est clôturée");
    }
}
