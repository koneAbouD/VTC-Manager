package com.tmk.vtcmanager.infrastructure.fcm;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Base64;

/**
 * Initialisation du SDK Firebase, uniquement lorsque l'envoi push est activé.
 *
 * <p>La clé de compte de service est fournie soit encodée en base64
 * ({@code app.push.credentials-base64}, ce que fait la production via son
 * {@code .env}), soit par un chemin de fichier pratique en développement. Elle
 * n'est jamais journalisée.
 */
@Slf4j
@Configuration
@ConditionalOnProperty(name = "app.push.enabled", havingValue = "true")
public class FirebaseConfig {

    @Bean
    public FirebaseMessaging firebaseMessaging(
            @Value("${app.push.credentials-base64:}") String credentialsBase64,
            @Value("${app.push.credentials-path:}") String credentialsPath) throws IOException {

        try (InputStream flux = ouvrirCleDeService(credentialsBase64, credentialsPath)) {
            FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(GoogleCredentials.fromStream(flux))
                    .build();

            // getApps() plutôt que initializeApp() seul : au rechargement de
            // contexte (tests, devtools), réinitialiser lèverait IllegalState.
            FirebaseApp app = FirebaseApp.getApps().isEmpty()
                    ? FirebaseApp.initializeApp(options)
                    : FirebaseApp.getInstance();

            log.info("Firebase initialisé : envoi des notifications push actif");
            return FirebaseMessaging.getInstance(app);
        }
    }

    private InputStream ouvrirCleDeService(String base64, String chemin) throws IOException {
        if (base64 != null && !base64.isBlank()) {
            return new ByteArrayInputStream(Base64.getDecoder().decode(base64.trim()));
        }
        if (chemin != null && !chemin.isBlank()) {
            Path fichier = Path.of(chemin).toAbsolutePath();
            if (!Files.isReadable(fichier)) {
                throw new IllegalStateException(
                        "Clé de compte de service Firebase introuvable : " + fichier
                                + " (app.push.credentials-path). Déposez-la à cet emplacement, "
                                + "surchargez FCM_CREDENTIALS_PATH, ou démarrez avec PUSH_ENABLED=false.");
            }
            return Files.newInputStream(fichier);
        }
        throw new IllegalStateException(
                "app.push.enabled=true mais aucune clé de compte de service fournie "
                        + "(renseignez app.push.credentials-base64 ou app.push.credentials-path).");
    }
}
