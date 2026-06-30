package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.penalite.LignePenalite;
import com.tmk.vtcmanager.application.domain.penalite.StatutLignePenalite;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementPenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import lombok.RequiredArgsConstructor;

/**
 * Lorsqu'une opération d'encaissement (recette / cotisation / pénalité) est
 * annulée, l'encaissement sous-jacent n'a plus de réalité comptable : on le
 * supprime et on recalcule la ligne correspondante.
 * <p>
 * No-op pour les opérations non liées à un encaissement (dépense, maintenance,
 * opération manuelle).
 */
@RequiredArgsConstructor
public class AnnulationEncaissementService {

    private static final String CODE_RECETTE    = "ENCAISSEMENT_RECETTES";
    private static final String CODE_COTISATION = "ENCAISSEMENT_COTISATIONS";
    private static final String CODE_PENALITE   = "ENCAISSEMENT_PENALITES";

    private final EncaissementRepository encaissementRepository;
    private final EncaissementCotisationRepository encaissementCotisationRepository;
    private final EncaissementPenaliteRepository encaissementPenaliteRepository;
    private final LigneRecetteRepository ligneRecetteRepository;
    private final LigneCotisationRepository ligneCotisationRepository;
    private final LignePenaliteRepository lignePenaliteRepository;

    public void annulerEncaissementLie(OperationFinanciere operation) {
        if (operation == null || operation.getCategorie() == null
                || operation.getCategorie().getCode() == null) {
            return;
        }
        Long opId = operation.getId();
        switch (operation.getCategorie().getCode()) {
            case CODE_RECETTE    -> annulerRecette(opId);
            case CODE_COTISATION -> annulerCotisation(opId);
            case CODE_PENALITE   -> annulerPenalite(opId);
            default -> { /* opération non liée à un encaissement → rien à faire */ }
        }
    }

    private void annulerRecette(Long opId) {
        var enc = encaissementRepository.findByOperationFinanciereId(opId).orElse(null);
        if (enc == null) return;
        Long ligneId = enc.getLigneRecetteId();
        encaissementRepository.deleteById(enc.getId());

        LigneRecette ligne = ligneRecetteRepository.findById(ligneId).orElse(null);
        if (ligne == null || ligne.getStatut() == StatutLigneRecette.ANNULEE) return;
        // Rechargement FRAIS des encaissements restants (post-suppression).
        ligne.setEncaissements(encaissementRepository.findByLigneRecetteId(ligneId));
        ligne.recalculerStatutEtMontant();
        ligneRecetteRepository.updateStatutAndMontantEncaisse(
                ligneId, ligne.getStatut(), ligne.getMontantEncaisse());
    }

    private void annulerCotisation(Long opId) {
        var enc = encaissementCotisationRepository.findByOperationFinanciereId(opId).orElse(null);
        if (enc == null) return;
        Long ligneId = enc.getLigneCotisationId();
        encaissementCotisationRepository.deleteById(enc.getId());

        LigneCotisation ligne = ligneCotisationRepository.findById(ligneId).orElse(null);
        if (ligne == null || ligne.getStatut() == StatutLigneCotisation.ANNULEE) return;
        ligne.setEncaissements(encaissementCotisationRepository.findByLigneCotisationId(ligneId));
        ligne.recalculerStatutEtMontant();
        ligneCotisationRepository.updateStatutAndMontantEncaisse(
                ligneId, ligne.getStatut(), ligne.getMontantEncaisse());
    }

    private void annulerPenalite(Long opId) {
        var enc = encaissementPenaliteRepository.findByOperationFinanciereId(opId).orElse(null);
        if (enc == null) return;
        Long ligneId = enc.getLignePenaliteId();
        encaissementPenaliteRepository.deleteById(enc.getId());

        LignePenalite ligne = lignePenaliteRepository.findById(ligneId).orElse(null);
        if (ligne == null || ligne.getStatut() == StatutLignePenalite.ANNULEE) return;
        ligne.setEncaissements(encaissementPenaliteRepository.findByLignePenaliteId(ligneId));
        ligne.recalculerStatutAmende();
        lignePenaliteRepository.updateStatutAndMontantEncaisse(
                ligneId, ligne.getStatut(), ligne.getMontantEncaisse());
    }
}
