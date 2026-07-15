package com.tmk.vtcmanager.infrastructure.payment;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.tmk.vtcmanager.application.domain.payment.InitiationResult;
import com.tmk.vtcmanager.application.domain.payment.NotificationResult;
import com.tmk.vtcmanager.application.domain.payment.PaiementInitiationCommand;
import com.tmk.vtcmanager.application.domain.payment.StatutPaiement;
import com.tmk.vtcmanager.application.exception.PaiementException;
import com.tmk.vtcmanager.application.ports.payment.PaymentGatewayPort;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import java.util.Map;

/**
 * Passerelle de paiement <b>simulée</b> — permet de dérouler le flux de bout en
 * bout sans compte agrégateur. À remplacer par un adapter réel (CinetPay,
 * PayDunya, Hub2…) en changeant {@code app.payment.provider}.
 *
 * <ul>
 *   <li>{@code initier} : renvoie EN_ATTENTE + une référence « SIM-… ».</li>
 *   <li>{@code verifierStatut} : renvoie REUSSI si {@code auto-success=true}
 *       (le polling conclut alors le paiement), sinon EN_ATTENTE.</li>
 *   <li>{@code interpreterNotification} : lit {reference, statut} du corps JSON
 *       (endpoint webhook de simulation), sans vérification de signature.</li>
 * </ul>
 */
@Slf4j
@Component
@ConditionalOnProperty(name = "app.payment.provider", havingValue = "simulation", matchIfMissing = true)
public class SimulationPaymentGatewayAdapter implements PaymentGatewayPort {

    private final ObjectMapper objectMapper;
    private final boolean autoSuccess;

    public SimulationPaymentGatewayAdapter(
            ObjectMapper objectMapper,
            @Value("${app.payment.simulation.auto-success:true}") boolean autoSuccess) {
        this.objectMapper = objectMapper;
        this.autoSuccess = autoSuccess;
        log.info("Passerelle de paiement : SIMULATION (auto-success={})", autoSuccess);
    }

    @Override
    public InitiationResult initier(PaiementInitiationCommand command) {
        return new InitiationResult(
                "SIM-" + command.reference(),
                StatutPaiement.EN_ATTENTE,
                null,
                "Paiement simulé en attente");
    }

    @Override
    public NotificationResult interpreterNotification(String rawPayload, Map<String, String> headers) {
        try {
            JsonNode node = objectMapper.readTree(rawPayload == null ? "{}" : rawPayload);
            String reference = node.path("reference").asText(null);
            String statutTexte = node.path("statut").asText("REUSSI");
            StatutPaiement statut = StatutPaiement.valueOf(statutTexte);
            return new NotificationResult(reference, null, statut, "Notification simulée");
        } catch (Exception e) {
            throw new PaiementException("Notification simulée invalide : " + e.getMessage());
        }
    }

    @Override
    public StatutPaiement verifierStatut(String gatewayReference) {
        return autoSuccess ? StatutPaiement.REUSSI : StatutPaiement.EN_ATTENTE;
    }
}
