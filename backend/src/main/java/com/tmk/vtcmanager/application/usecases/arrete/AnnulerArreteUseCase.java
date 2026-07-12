package com.tmk.vtcmanager.application.usecases.arrete;

import com.tmk.vtcmanager.application.domain.arrete.ArreteCompte;
import com.tmk.vtcmanager.application.domain.arrete.LigneArrete;
import com.tmk.vtcmanager.application.domain.arrete.SensArrete;
import com.tmk.vtcmanager.application.domain.arrete.StatutArrete;
import com.tmk.vtcmanager.application.domain.contravention.Contravention;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.ports.persistence.ArreteCompteRepository;
import com.tmk.vtcmanager.application.ports.persistence.ContraventionRepository;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementPenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.services.PeriodeClotureeGuard;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

/**
 * Annule un arrêté de compte (avec motif obligatoire) en contre-passant tous ses
 * effets : les décaissements et les opérations de compensation sont annulés, les
 * créances rouvertes (recalcul depuis les encaissements restants) et les
 * cotisations repassées de RESTITUEE à leur statut d'origine. Refusé si la
 * période de l'arrêté est clôturée.
 */
@RequiredArgsConstructor
public class AnnulerArreteUseCase {

    private final ArreteCompteRepository arreteCompteRepository;
    private final LigneCotisationRepository ligneCotisationRepository;
    private final LigneRecetteRepository ligneRecetteRepository;
    private final EncaissementRepository encaissementRepository;
    private final LignePenaliteRepository lignePenaliteRepository;
    private final EncaissementPenaliteRepository encaissementPenaliteRepository;
    private final ContraventionRepository contraventionRepository;
    private final OperationFinanciereRepository operationFinanciereRepository;
    private final PeriodeClotureeGuard periodeClotureeGuard;

    @Transactional
    public ArreteCompte executer(Long arreteId, String motif) {
        if (motif == null || motif.isBlank()) {
            throw new IllegalArgumentException("Le motif d'annulation est obligatoire.");
        }
        ArreteCompte arrete = arreteCompteRepository.findById(arreteId)
                .orElseThrow(() -> new IllegalArgumentException("Arrêté introuvable : " + arreteId));
        if (arrete.getStatut() == StatutArrete.ANNULE) {
            throw new IllegalStateException("Cet arrêté est déjà annulé.");
        }
        periodeClotureeGuard.verifier(arrete.getDateArrete());

        // 1. Contre-passe les décaissements (« primes »).
        arrete.getReglements().forEach(r -> annulerOperation(r.getOperationDecaissementId()));

        // 2. Rouvre les créances compensées (contre-passe les encaissements cash-neutres).
        arrete.getLignes().stream()
                .filter(l -> l.getSens() == SensArrete.DEBIT)
                .forEach(this::reverserCompensation);

        // 3. Repasse les cotisations RESTITUEE à leur statut d'origine.
        arrete.getLignes().stream()
                .filter(l -> l.getSens() == SensArrete.CREDIT)
                .forEach(l -> ligneCotisationRepository.annulerRestitution(l.getDocumentId()));

        arreteCompteRepository.annuler(arreteId, motif);
        return arreteCompteRepository.findById(arreteId).orElse(arrete);
    }

    private void reverserCompensation(LigneArrete ligne) {
        switch (ligne.getDocument()) {
            case RECETTE -> {
                if (ligne.getOperationId() != null) {
                    encaissementRepository.findByOperationFinanciereId(ligne.getOperationId())
                            .ifPresent(e -> encaissementRepository.deleteById(e.getId()));
                    annulerOperation(ligne.getOperationId());
                }
                ligneRecetteRepository.recalculerDepuisEncaissements(ligne.getDocumentId());
            }
            case PENALITE -> {
                if (ligne.getOperationId() != null) {
                    encaissementPenaliteRepository.findByOperationFinanciereId(ligne.getOperationId())
                            .ifPresent(e -> encaissementPenaliteRepository.deleteById(e.getId()));
                    annulerOperation(ligne.getOperationId());
                }
                lignePenaliteRepository.recalculerDepuisEncaissements(ligne.getDocumentId());
            }
            case CONTRAVENTION -> {
                Contravention contravention = contraventionRepository.findById(ligne.getDocumentId())
                        .orElseThrow(() -> new IllegalStateException(
                                "Contravention introuvable : " + ligne.getDocumentId()));
                contravention.annulerPaiement(ligne.getMontant());
                contraventionRepository.save(contravention);
                annulerOperation(ligne.getOperationId());
            }
            case COTISATION -> { /* pas de créance : ligne de crédit */ }
        }
    }

    private void annulerOperation(Long operationId) {
        if (operationId == null) return;
        operationFinanciereRepository.findById(operationId).ifPresent(op -> {
            if (op.getStatut() != StatutOperation.ANNULEE) {
                op.setStatut(StatutOperation.ANNULEE);
                operationFinanciereRepository.save(op);
            }
        });
    }
}
