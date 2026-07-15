package com.tmk.vtcmanager.application.usecases.payment;

import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.payment.CanalPaiement;
import com.tmk.vtcmanager.application.domain.payment.InitiationResult;
import com.tmk.vtcmanager.application.domain.payment.Paiement;
import com.tmk.vtcmanager.application.domain.payment.PaiementInitiationCommand;
import com.tmk.vtcmanager.application.domain.payment.StatutPaiement;
import com.tmk.vtcmanager.application.domain.payment.TypeCiblePaiement;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.exception.PaiementException;
import com.tmk.vtcmanager.application.ports.payment.PaymentGatewayPort;
import com.tmk.vtcmanager.application.ports.persistence.PaiementRepository;
import com.tmk.vtcmanager.application.usecases.cotisation.GetLignesCotisationUseCase;
import com.tmk.vtcmanager.application.usecases.recette.GetLignesRecetteUseCase;
import lombok.RequiredArgsConstructor;

import java.math.BigDecimal;
import java.security.SecureRandom;
import java.time.LocalDateTime;

/**
 * Initie un paiement Mobile Money pour régler une recette ou une cotisation du
 * chauffeur courant. Le montant est calculé côté serveur (reste dû) : le client
 * ne le fournit pas. Le paiement est persisté puis transmis à l'agrégateur.
 */
@RequiredArgsConstructor
public class InitierPaiementUseCase {

    private static final SecureRandom RANDOM = new SecureRandom();

    private final PaiementRepository paiementRepository;
    private final PaymentGatewayPort paymentGatewayPort;
    private final GetLignesRecetteUseCase getLignesRecetteUseCase;
    private final GetLignesCotisationUseCase getLignesCotisationUseCase;
    /** URL publique du webhook agrégateur (base + provider). */
    private final String callbackUrl;

    public Paiement executer(Long chauffeurId, TypeCiblePaiement typeCible, Long cibleId,
                             CanalPaiement canal, String telephone) {
        if (telephone == null || telephone.isBlank()) {
            throw new PaiementException("Numéro de téléphone requis pour le paiement.");
        }

        BigDecimal montant;
        Long vehiculeId;
        String description;

        if (typeCible == TypeCiblePaiement.RECETTE) {
            LigneRecette ligne = getLignesRecetteUseCase.findById(cibleId);
            verifierProprietaire(chauffeurId, ligne.getChauffeurId());
            if (!ligne.estActive()) {
                throw new PaiementException("Cette recette est déjà soldée ou annulée.");
            }
            if (ligne.getMontantAttendu() == null) {
                throw new PaiementException("Recette à montant réel : paiement non applicable.");
            }
            montant = ligne.getMontantAttendu().subtract(ligne.getMontantEncaisse());
            vehiculeId = ligne.getVehiculeId();
            description = "Recette du " + ligne.getDateRecette();
        } else {
            LigneCotisation ligne = getLignesCotisationUseCase.findById(cibleId);
            verifierProprietaire(chauffeurId, ligne.getChauffeurId());
            if (!ligne.estActive()) {
                throw new PaiementException("Cette cotisation est déjà soldée ou annulée.");
            }
            montant = ligne.getMontantDu().subtract(ligne.getMontantEncaisse());
            vehiculeId = ligne.getVehiculeId();
            description = ligne.getNomCotisation();
        }

        if (montant == null || montant.signum() <= 0) {
            throw new PaiementException("Aucun montant restant à payer.");
        }

        String reference = genererReference();
        Paiement paiement = Paiement.builder()
                .reference(reference)
                .typeCible(typeCible)
                .cibleId(cibleId)
                .chauffeurId(chauffeurId)
                .vehiculeId(vehiculeId)
                .montant(montant)
                .canal(canal)
                .telephone(telephone)
                .statut(StatutPaiement.INITIE)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();
        paiement = paiementRepository.save(paiement);

        // Appel agrégateur.
        InitiationResult res = paymentGatewayPort.initier(new PaiementInitiationCommand(
                reference, montant, canal, telephone, description, callbackUrl));

        paiement.setGatewayReference(res.gatewayReference());
        paiement.setPaymentUrl(res.paymentUrl());
        paiement.setStatut(res.statut() != null ? res.statut() : StatutPaiement.EN_ATTENTE);
        paiement.setMessageErreur(res.message());
        paiement.setUpdatedAt(LocalDateTime.now());
        return paiementRepository.save(paiement);
    }

    private void verifierProprietaire(Long chauffeurId, Long ligneChauffeurId) {
        if (ligneChauffeurId == null || !ligneChauffeurId.equals(chauffeurId)) {
            throw new PaiementException("Cette ligne n'appartient pas au chauffeur.");
        }
    }

    private String genererReference() {
        return "PAY-" + System.currentTimeMillis() + "-" + (1000 + RANDOM.nextInt(9000));
    }
}
