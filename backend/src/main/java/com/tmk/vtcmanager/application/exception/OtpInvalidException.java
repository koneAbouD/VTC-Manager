package com.tmk.vtcmanager.application.exception;

/** Code OTP invalide, expiré ou déjà consommé (HTTP 401). */
public class OtpInvalidException extends RuntimeException {

    public OtpInvalidException(String message) {
        super(message);
    }
}
