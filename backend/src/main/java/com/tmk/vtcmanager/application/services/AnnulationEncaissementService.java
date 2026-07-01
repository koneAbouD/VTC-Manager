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

    private final EncaissementRepository encaissementRepository;
    private final EncaissementCotisationRepository encaissementCotisationRepository;
    private final EncaissementPenaliteRepository encaissementPenaliteRepository;
    private final LigneRecetteRepository ligneRecetteRepository;
    private final LigneCotisationRepository ligneCotisationRepository;
    private final LignePenaliteRepository lignePenaliteRepository;

    public void annulerEncaissementLie(OperationFinanciere operation) {
        if (operation == null || operation.getId() == null) {
            return;
        }
        Long opId = operation.getId();
        // On sonde directement les 3 tables d'encaissement par operationFinanciereId,
        // sans se fier au code catégorie de l'opération. Une opération dont la
        // catégorie a changé (donnée héritée) conserverait sinon un encaissement
        // enfant orphelin, bloquant sa suppression (FK fk_encaissements_operation).
        // Chaque méthode est un no-op si aucun encaissement lié n'existe.
        annulerRecette(opId);
        annulerCotisation(opId);
        annulerPenalite(opId);
    }

    private void annulerRecette(Long opId) {
        var enc = encaissementRepository.findByOperationFinanciereId(opId).orElse(null);
        if (enc == null) return;
        Long ligneId = enc.getLigneRecetteId();

        // Encaissements restants = tous ceux de la ligne SAUF celui annulé,
        // calculés explicitement (et non par un rechargement post-delete) : la
        // suppression n'est pas garantie flushée avant la relecture, ce qui
        // laisserait l'encaissement annulé dans le recalcul (ligne non restaurée).
        var restants = encaissementRepository.findByLigneRecetteId(ligneId).stream()
                .filter(e -> !e.getId().equals(enc.getId()))
                .toList();

        encaissementRepository.deleteById(enc.getId());

        LigneRecette ligne = ligneRecetteRepository.findById(ligneId).orElse(null);
        if (ligne == null || ligne.getStatut() == StatutLigneRecette.ANNULEE) return;
        ligne.setEncaissements(restants);
        ligne.recalculerStatutEtMontant();
        ligneRecetteRepository.updateStatutAndMontantEncaisse(
                ligneId, ligne.getStatut(), ligne.getMontantEncaisse());
    }

    private void annulerCotisation(Long opId) {
        var enc = encaissementCotisationRepository.findByOperationFinanciereId(opId).orElse(null);
        if (enc == null) return;
        Long ligneId = enc.getLigneCotisationId();

        var restants = encaissementCotisationRepository.findByLigneCotisationId(ligneId).stream()
                .filter(e -> !e.getId().equals(enc.getId()))
                .toList();

        encaissementCotisationRepository.deleteById(enc.getId());

        LigneCotisation ligne = ligneCotisationRepository.findById(ligneId).orElse(null);
        if (ligne == null || ligne.getStatut() == StatutLigneCotisation.ANNULEE) return;
        ligne.setEncaissements(restants);
        ligne.recalculerStatutEtMontant();
        ligneCotisationRepository.updateStatutAndMontantEncaisse(
                ligneId, ligne.getStatut(), ligne.getMontantEncaisse());
    }

    private void annulerPenalite(Long opId) {
        var enc = encaissementPenaliteRepository.findByOperationFinanciereId(opId).orElse(null);
        if (enc == null) return;
        Long ligneId = enc.getLignePenaliteId();

        var restants = encaissementPenaliteRepository.findByLignePenaliteId(ligneId).stream()
                .filter(e -> !e.getId().equals(enc.getId()))
                .toList();

        encaissementPenaliteRepository.deleteById(enc.getId());

        LignePenalite ligne = lignePenaliteRepository.findById(ligneId).orElse(null);
        if (ligne == null || ligne.getStatut() == StatutLignePenalite.ANNULEE) return;
        ligne.setEncaissements(restants);
        ligne.recalculerStatutAmende();
        lignePenaliteRepository.updateStatutAndMontantEncaisse(
                ligneId, ligne.getStatut(), ligne.getMontantEncaisse());
    }
}
