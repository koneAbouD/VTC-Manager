package com.tmk.vtcmanager.application.ports.auth;

/**
 * Port d'envoi d'un code OTP au chauffeur. Le canal (WhatsApp, SMS…) est
 * un détail d'infrastructure : l'application ne connaît que ce contrat.
 */
public interface OtpDeliveryPort {

    /**
     * Envoie le code {@code code} au numéro {@code telephone}.
     *
     * @throws com.tmk.vtcmanager.application.exception.OtpDeliveryException si l'envoi échoue.
     */
    void envoyer(String telephone, String code);
}
