package com.tmk.vtcmanager.application.usecases.penalite;

import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import com.tmk.vtcmanager.application.domain.modification.ModificationMontant;
import com.tmk.vtcmanager.application.domain.penalite.LignePenalite;
import com.tmk.vtcmanager.application.exception.LignePenaliteNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.ArreteCompteRepository;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.ModificationMontantRepository;
import com.tmk.vtcmanager.application.ports.security.AuteurCourant;
import com.tmk.vtcmanager.application.services.ModificationMontantService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;

/**
 * Corrige le montant d'une amende. Les versements ne bougent pas ; le statut
 * se relit sur ce qui a été encaissé. La correction est consignée avec son
 * motif.
 */
@Slf4j
@RequiredArgsConstructor
public class ModifierMontantPenaliteUseCase {

    private final LignePenaliteRepository lignePenaliteRepository;
    private final ArreteCompteRepository arreteCompteRepository;
    private final ModificationMontantRepository modificationMontantRepository;
    private final ModificationMontantService modificationMontantService;
    private final AuteurCourant auteurCourant;

    @Transactional
    public LignePenalite executer(Long ligneId, BigDecimal nouveauMontant, String motif) {
        if (motif == null || motif.isBlank()) {
            throw new IllegalArgumentException("Le motif de la correction est obligatoire.");
        }
        arreteCompteRepository.verrouillerExecution();

        LignePenalite ligne = lignePenaliteRepository.findById(ligneId)
                .orElseThrow(() -> new LignePenaliteNotFoundException(ligneId));
        BigDecimal ancien = ligne.getMontant() != null ? ligne.getMontant() : BigDecimal.ZERO;
        if (nouveauMontant != null && ancien.compareTo(nouveauMontant) == 0) {
            return ligne;
        }

        String blocage = modificationMontantService.motifBlocage(ligne);
        if (blocage != null) throw new IllegalStateException(blocage);
        modificationMontantService.verifierMontant(nouveauMontant, ligne.getMontantEncaisse());

        lignePenaliteRepository.modifierMontant(ligneId, nouveauMontant);
        lignePenaliteRepository.recalculerDepuisEncaissements(ligneId);
        String auteur = auteurCourant.nom();
        modificationMontantRepository.enregistrer(ModificationMontant.builder()
                .document(TypeDocumentCreance.PENALITE)
                .documentId(ligneId)
                .ancienMontant(ancien)
                .nouveauMontant(nouveauMontant)
                .motif(motif.trim())
                .createdBy(auteur)
                .build());
        log.info("Pénalité {} : montant {} → {} par {}", ligneId, ancien, nouveauMontant, auteur);

        return lignePenaliteRepository.findById(ligneId)
                .orElseThrow(() -> new LignePenaliteNotFoundException(ligneId));
    }
}
