package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
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
 * supprime, puis on recalcule montant_encaisse + statut de la ligne
 * DIRECTEMENT depuis la table des encaissements (source de vérité), en une
 * instruction atomique — sans manipuler de liste en mémoire (source des
 * incohérences précédentes).
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
        // On sonde les 3 tables par operationFinanciereId (indépendant du code
        // catégorie). Chaque méthode est un no-op si aucun encaissement lié.
        annulerRecette(opId);
        annulerCotisation(opId);
        annulerPenalite(opId);
    }

    private void annulerRecette(Long opId) {
        var enc = encaissementRepository.findByOperationFinanciereId(opId).orElse(null);
        if (enc == null) return;
        Long ligneId = enc.getLigneRecetteId();
        encaissementRepository.deleteById(enc.getId());
        // Recalcul fiable depuis la BDD (le flush du delete est garanti avant le SUM).
        ligneRecetteRepository.recalculerDepuisEncaissements(ligneId);
    }

    private void annulerCotisation(Long opId) {
        var enc = encaissementCotisationRepository.findByOperationFinanciereId(opId).orElse(null);
        if (enc == null) return;
        Long ligneId = enc.getLigneCotisationId();
        encaissementCotisationRepository.deleteById(enc.getId());
        ligneCotisationRepository.recalculerDepuisEncaissements(ligneId);
    }

    private void annulerPenalite(Long opId) {
        var enc = encaissementPenaliteRepository.findByOperationFinanciereId(opId).orElse(null);
        if (enc == null) return;
        Long ligneId = enc.getLignePenaliteId();
        encaissementPenaliteRepository.deleteById(enc.getId());
        lignePenaliteRepository.recalculerDepuisEncaissements(ligneId);
    }
}
