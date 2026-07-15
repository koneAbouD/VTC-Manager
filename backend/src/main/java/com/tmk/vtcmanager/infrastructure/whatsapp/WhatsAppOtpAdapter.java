package com.tmk.vtcmanager.infrastructure.whatsapp;

import com.tmk.vtcmanager.application.exception.OtpDeliveryException;
import com.tmk.vtcmanager.application.ports.auth.OtpDeliveryPort;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

import java.util.List;
import java.util.Map;

/**
 * Envoi d'OTP via l'API WhatsApp Cloud de Meta (Graph API), avec un template
 * de catégorie AUTHENTICATION (code en corps + bouton « copier le code »).
 *
 * En dev, si {@code app.whatsapp.enabled=false}, le code est simplement journalisé
 * (aucun appel réseau) pour permettre de tester le flux sans WABA.
 */
@Slf4j
@Component
public class WhatsAppOtpAdapter implements OtpDeliveryPort {

    private final RestTemplate restTemplate;
    private final boolean enabled;
    private final String messagesUrl;
    private final String accessToken;
    private final String templateName;
    private final String templateLanguage;

    public WhatsAppOtpAdapter(
            RestTemplate restTemplate,
            @Value("${app.whatsapp.enabled:false}") boolean enabled,
            @Value("${app.whatsapp.api-url:https://graph.facebook.com}") String apiUrl,
            @Value("${app.whatsapp.api-version:v21.0}") String apiVersion,
            @Value("${app.whatsapp.phone-number-id:}") String phoneNumberId,
            @Value("${app.whatsapp.access-token:}") String accessToken,
            @Value("${app.whatsapp.template-name:otp_login}") String templateName,
            @Value("${app.whatsapp.template-language:fr}") String templateLanguage) {
        this.restTemplate = restTemplate;
        this.enabled = enabled;
        this.messagesUrl = apiUrl + "/" + apiVersion + "/" + phoneNumberId + "/messages";
        this.accessToken = accessToken;
        this.templateName = templateName;
        this.templateLanguage = templateLanguage;
    }

    @Override
    public void envoyer(String telephone, String code) {
        if (!enabled) {
            // Mode dev : pas de WABA. On journalise le code pour pouvoir tester.
            log.warn("[WhatsApp DÉSACTIVÉ] OTP pour {} = {} (activez app.whatsapp.enabled en prod)",
                    telephone, code);
            return;
        }

        Map<String, Object> body = Map.of(
                "messaging_product", "whatsapp",
                "to", toWhatsAppNumber(telephone),
                "type", "template",
                "template", Map.of(
                        "name", templateName,
                        "language", Map.of("code", templateLanguage),
                        "components", List.of(
                                Map.of("type", "body",
                                        "parameters", List.of(Map.of("type", "text", "text", code))),
                                Map.of("type", "button",
                                        "sub_type", "url",
                                        "index", "0",
                                        "parameters", List.of(Map.of("type", "text", "text", code)))
                        )
                )
        );

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.setBearerAuth(accessToken);

        try {
            restTemplate.postForEntity(messagesUrl, new HttpEntity<>(body, headers), String.class);
            log.info("OTP WhatsApp envoyé à {}", telephone);
        } catch (HttpClientErrorException e) {
            log.error("Échec envoi OTP WhatsApp à {} : {} - {}",
                    telephone, e.getStatusCode(), e.getResponseBodyAsString());
            throw new OtpDeliveryException("Échec de l'envoi WhatsApp", e);
        } catch (Exception e) {
            log.error("Échec envoi OTP WhatsApp à {} : {}", telephone, e.getMessage());
            throw new OtpDeliveryException("Échec de l'envoi WhatsApp", e);
        }
    }

    /** Meta attend le numéro au format international sans « + » ni espaces. */
    private String toWhatsAppNumber(String telephone) {
        String digits = telephone.replaceAll("[^0-9]", "");
        return digits;
    }
}
