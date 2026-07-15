package com.tmk.vtcmanager.interfaces.rest.payment;

import com.tmk.vtcmanager.application.usecases.payment.TraiterNotificationPaiementUseCase;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * Réception des notifications (webhooks) de l'agrégateur de paiement.
 * Endpoint public (pas de JWT) : la légitimité repose sur la vérification de
 * signature effectuée dans l'adapter d'agrégateur.
 */
@Slf4j
@RestController
@RequestMapping("/api/payments/webhook")
@RequiredArgsConstructor
@Tag(name = "Paiement (webhook)", description = "Notifications agrégateur Mobile Money")
public class PaiementWebhookController {

    private final TraiterNotificationPaiementUseCase traiterNotificationPaiementUseCase;

    @PostMapping("/{provider}")
    @Operation(summary = "Notification de paiement de l'agrégateur")
    public ResponseEntity<Void> notifier(
            @PathVariable String provider,
            @RequestBody(required = false) String payload,
            @RequestHeader Map<String, String> headers) {
        log.info("Webhook paiement reçu (provider={})", provider);
        traiterNotificationPaiementUseCase.traiter(payload, headers);
        return ResponseEntity.ok().build();
    }
}
