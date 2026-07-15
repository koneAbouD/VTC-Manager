package com.tmk.vtcmanager.application.usecases.payment;

import com.tmk.vtcmanager.application.domain.cotisation.EncaissementCotisation;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.payment.NotificationResult;
import com.tmk.vtcmanager.application.domain.payment.Paiement;
import com.tmk.vtcmanager.application.domain.payment.StatutPaiement;
import com.tmk.vtcmanager.application.domain.payment.TypeCiblePaiement;
import com.tmk.vtcmanager.application.domain.recette.Encaissement;
import com.tmk.vtcmanager.application.ports.payment.PaymentGatewayPort;
import com.tmk.vtcmanager.application.ports.persistence.PaiementRepository;
import com.tmk.vtcmanager.application.usecases.cotisation.CreateEncaissementCotisationUseCase;
import com.tmk.vtcmanager.application.usecases.recette.CreateEncaissementUseCase;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Map;
import java.util.Optional;

/**
 * Applique le statut d'un paiement (webhook agrégateur = source de vérité) et,
 * au succès, crée l'encaissement métier correspondant — de façon idempotente
 * (une seule fois, protégé par {@code encaissementId}).
 */
@Slf4j
@RequiredArgsConstructor
public class TraiterNotificationPaiementUseCase {

    private final PaiementRepository paiementRepository;
    private final PaymentGatewayPort paymentGatewayPort;
    private final CreateEncaissementUseCase createEncaissementUseCase;
    private final CreateEncaissementCotisationUseCase createEncaissementCotisationUseCase;

    /** Point d'entrée webhook. */
    @Transactional
    public void traiter(String rawPayload, Map<String, String> headers) {
        NotificationResult res = paymentGatewayPort.interpreterNotification(rawPayload, headers);

        Optional<Paiement> paiement = Optional.empty();
        if (res.reference() != null) {
            paiement = paiementRepository.findByReference(res.reference());
        }
        if (paiement.isEmpty() && res.gatewayReference() != null) {
            paiement = paiementRepository.findByGatewayReference(res.gatewayReference());
        }
        if (paiement.isEmpty()) {
            log.warn("Notification paiement sans correspondance (ref={}, gwRef={})",
                    res.reference(), res.gatewayReference());
            return;
        }
        appliquer(paiement.get(), res.statut(), res.message());
    }

    /**
     * Applique un statut à un paiement (idempotent) et déclenche l'encaissement
     * au premier passage à REUSSI. Réutilisé par le polling / la réconciliation.
     */
    @Transactional
    public Paiement appliquer(Paiement paiement, StatutPaiement nouveau, String message) {
        if (nouveau == null || paiement.getStatut().estTerminal()) {
            return paiement; // déjà résolu : rien à faire.
        }
        paiement.setStatut(nouveau);
        paiement.setMessageErreur(message);
        paiement.setUpdatedAt(LocalDateTime.now());

        if (nouveau == StatutPaiement.REUSSI && paiement.getEncaissementId() == null) {
            Long encaissementId = creerEncaissement(paiement);
            paiement.setEncaissementId(encaissementId);
        }
        return paiementRepository.save(paiement);
    }

    private Long creerEncaissement(Paiement paiement) {
        String commentaire = "Paiement Mobile Money " + paiement.getReference()
                + " (" + paiement.getCanal() + ")";
        if (paiement.getTypeCible() == TypeCiblePaiement.RECETTE) {
            Encaissement enc = createEncaissementUseCase.executer(paiement.getCibleId(),
                    Encaissement.builder()
                            .montant(paiement.getMontant())
                            .modeEncaissement(ModePaiement.MOBILE_MONEY)
                            .dateEncaissement(LocalDate.now())
                            .commentaire(commentaire)
                            .build());
            return enc.getId();
        }
        EncaissementCotisation enc = createEncaissementCotisationUseCase.executer(paiement.getCibleId(),
                EncaissementCotisation.builder()
                        .montant(paiement.getMontant())
                        .modeEncaissement(ModePaiement.MOBILE_MONEY)
                        .dateEncaissement(LocalDate.now())
                        .commentaire(commentaire)
                        .build());
        return enc.getId();
    }
}
