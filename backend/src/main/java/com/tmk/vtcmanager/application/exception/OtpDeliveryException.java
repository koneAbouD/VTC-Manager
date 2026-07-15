package com.tmk.vtcmanager.application.exception;

/** Levée lorsque l'envoi du code OTP (WhatsApp) échoue côté fournisseur. */
public class OtpDeliveryException extends RuntimeException {

    public OtpDeliveryException(String message) {
        super(message);
    }

    public OtpDeliveryException(String message, Throwable cause) {
        super(message, cause);
    }
}
