package com.tmk.vtcmanager.application.usecases.payment;

import com.tmk.vtcmanager.application.domain.payment.Paiement;
import com.tmk.vtcmanager.application.domain.payment.StatutPaiement;
import com.tmk.vtcmanager.application.exception.PaiementException;
import com.tmk.vtcmanager.application.ports.payment.PaymentGatewayPort;
import com.tmk.vtcmanager.application.ports.persistence.PaiementRepository;
import lombok.RequiredArgsConstructor;

/**
 * Statut d'un paiement pour le chauffeur courant. Si le paiement n'est pas
 * encore résolu, on interroge l'agrégateur (polling de secours si le webhook
 * n'est pas arrivé) et on applique le statut obtenu.
 */
@RequiredArgsConstructor
public class GetStatutPaiementUseCase {

    private final PaiementRepository paiementRepository;
    private final PaymentGatewayPort paymentGatewayPort;
    private final TraiterNotificationPaiementUseCase traiterNotificationPaiementUseCase;

    public Paiement executer(Long chauffeurId, String reference) {
        Paiement paiement = paiementRepository.findByReference(reference)
                .filter(p -> p.appartientA(chauffeurId))
                .orElseThrow(() -> new PaiementException("Paiement introuvable : " + reference));

        if (!paiement.getStatut().estTerminal() && paiement.getGatewayReference() != null) {
            StatutPaiement statut = paymentGatewayPort.verifierStatut(paiement.getGatewayReference());
            paiement = traiterNotificationPaiementUseCase.appliquer(paiement, statut, null);
        }
        return paiement;
    }

    public java.util.List<Paiement> historique(Long chauffeurId) {
        return paiementRepository.findByChauffeurId(chauffeurId);
    }
}
