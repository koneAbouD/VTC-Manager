package com.tmk.vtcmanager.application.domain.common;

/**
 * Normalisation des numéros de téléphone ivoiriens vers une forme canonique.
 *
 * Les numéros peuvent être saisis/stockés sous plusieurs formes :
 *   « 0707070707 », « +225 07 07 07 07 07 », « 2250707070707 »…
 * On les réduit à une forme canonique E.164 sans « + » (ex. « 2250707070707 »)
 * et on expose la forme locale (« 0707070707 ») pour les rapprochements en base.
 */
public final class PhoneNumberNormalizer {

    private static final String INDICATIF_CI = "225";

    private PhoneNumberNormalizer() {
    }

    /** Réduit une saisie à ses seuls chiffres. */
    public static String chiffres(String input) {
        return input == null ? "" : input.replaceAll("[^0-9]", "");
    }

    /**
     * Forme canonique : indicatif pays « 225 » suivi du numéro d'abonné (10 chiffres en CI).
     * Idempotent : « 0707070707 » et « 2250707070707 » donnent la même sortie.
     */
    public static String canonique(String input) {
        String d = chiffres(input);
        if (d.isEmpty()) {
            return d;
        }
        if (d.startsWith(INDICATIF_CI)) {
            return d;
        }
        // Numéro local (avec ou sans 0 initial) → préfixer l'indicatif.
        return INDICATIF_CI + d;
    }

    /**
     * Forme locale (sans indicatif) telle qu'elle est souvent stockée en base.
     * Ex. « 2250707070707 » → « 0707070707 ».
     */
    public static String local(String input) {
        String d = chiffres(input);
        if (d.startsWith(INDICATIF_CI)) {
            return d.substring(INDICATIF_CI.length());
        }
        return d;
    }
}
