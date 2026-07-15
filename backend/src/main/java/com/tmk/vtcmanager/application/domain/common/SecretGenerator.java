package com.tmk.vtcmanager.application.domain.common;

import java.security.SecureRandom;
import java.util.Base64;

/** Génération de secrets cryptographiquement sûrs (codes OTP, mots de passe éphémères). */
public final class SecretGenerator {

    private static final SecureRandom RANDOM = new SecureRandom();

    private SecretGenerator() {
    }

    /** Code numérique de {@code longueur} chiffres (avec zéros de tête possibles). */
    public static String codeNumerique(int longueur) {
        StringBuilder sb = new StringBuilder(longueur);
        for (int i = 0; i < longueur; i++) {
            sb.append(RANDOM.nextInt(10));
        }
        return sb.toString();
    }

    /** Mot de passe aléatoire fort (base64url), jamais connu de l'utilisateur. */
    public static String motDePasseEphemere() {
        byte[] bytes = new byte[24];
        RANDOM.nextBytes(bytes);
        return "Aa1!" + Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }
}
