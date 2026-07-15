package com.tmk.vtcmanager.application.domain.common;

import java.nio.charset.StandardCharsets;
import java.util.Base64;

/**
 * Lecture <b>non vérifiée</b> du payload d'un JWT (le token vient d'être émis par
 * Keycloak, sa signature n'a pas à être revalidée ici). Sert uniquement à extraire
 * le claim {@code sub} juste après un grant.
 */
public final class JwtPayloadReader {

    private JwtPayloadReader() {
    }

    /** Extrait le claim {@code sub}, ou {@code null} si le token est illisible. */
    public static String sub(String accessToken) {
        try {
            String[] parts = accessToken.split("\\.");
            if (parts.length < 2) return null;
            String json = new String(
                    Base64.getUrlDecoder().decode(parts[1]), StandardCharsets.UTF_8);
            // Extraction minimale sans dépendance JSON : "sub":"...".
            int i = json.indexOf("\"sub\"");
            if (i < 0) return null;
            int colon = json.indexOf(':', i);
            int firstQuote = json.indexOf('"', colon + 1);
            int secondQuote = json.indexOf('"', firstQuote + 1);
            if (firstQuote < 0 || secondQuote < 0) return null;
            return json.substring(firstQuote + 1, secondQuote);
        } catch (Exception e) {
            return null;
        }
    }
}
