package com.tmk.vtcmanager.application.exception;

import java.time.LocalDate;

public class ClotureCaisseDejaEffectueeException extends RuntimeException {

    public ClotureCaisseDejaEffectueeException(LocalDate date) {
        super("La caisse a déjà été clôturée le " + date);
    }
}
