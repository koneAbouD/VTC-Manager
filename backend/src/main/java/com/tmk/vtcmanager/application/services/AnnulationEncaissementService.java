package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementPenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import lombok.RequiredArgsConstructor;

import java.time.LocalDateTime;

/**
 * Lorsqu'une écriture d'encaissement (recette / cotisation / pénalité) est
 * contre-passée, l'encaissement sous-jacent est <em>marqué annulé</em> — avec
 * son auteur et son motif — et jamais supprimé : un règlement reçu puis annulé
 * reste un fait, seule sa portée comptable disparaît.
 *
 * <p>Le montant encaissé et le statut de la ligne sont ensuite recalculés
 * DIRECTEMENT depuis la table des encaissements (source de vérité), qui ne
 * somme que les encaissements actifs — en une instruction atomique, sans
 * manipuler de liste en mémoire.
 *
 * <p>No-op pour les opérations non liées à un encaissement (dépense,
 * maintenance, opération manuelle).
 */
@RequiredArgsConstructor
public class AnnulationEncaissementService {

    private final EncaissementRepository encaissementRepository;
    private final EncaissementCotisationRepository encaissementCotisationRepository;
    private final EncaissementPenaliteRepository encaissementPenaliteRepository;
    private final LigneRecetteRepository ligneRecetteRepository;
    private final LigneCotisationRepository ligneCotisationRepository;
    private final LignePenaliteRepository lignePenaliteRepository;

    public void annulerEncaissementLie(OperationFinanciere operation, String auteur, String motif) {
        if (operation == null || operation.getId() == null) {
            return;
        }
        Long opId = operation.getId();
        // On sonde les 3 tables par operationFinanciereId (indépendant du code
        // catégorie). Chaque méthode est un no-op si aucun encaissement lié.
        annulerRecette(opId, auteur, motif);
        annulerCotisation(opId, auteur, motif);
        annulerPenalite(opId, auteur, motif);
    }

    private void annulerRecette(Long opId, String auteur, String motif) {
        var enc = encaissementRepository.findByOperationFinanciereId(opId).orElse(null);
        if (enc == null || enc.getAnnuleLe() != null) return;
        enc.setAnnuleLe(LocalDateTime.now());
        enc.setAnnulePar(auteur);
        enc.setMotifAnnulation(motif);
        encaissementRepository.save(enc);
        // Recalcul fiable depuis la BDD (le flush du marquage est garanti avant le SUM).
        ligneRecetteRepository.recalculerDepuisEncaissements(enc.getLigneRecetteId());
    }

    private void annulerCotisation(Long opId, String auteur, String motif) {
        var enc = encaissementCotisationRepository.findByOperationFinanciereId(opId).orElse(null);
        if (enc == null || enc.getAnnuleLe() != null) return;
        enc.setAnnuleLe(LocalDateTime.now());
        enc.setAnnulePar(auteur);
        enc.setMotifAnnulation(motif);
        encaissementCotisationRepository.save(enc);
        ligneCotisationRepository.recalculerDepuisEncaissements(enc.getLigneCotisationId());
    }

    private void annulerPenalite(Long opId, String auteur, String motif) {
        var enc = encaissementPenaliteRepository.findByOperationFinanciereId(opId).orElse(null);
        if (enc == null || enc.getAnnuleLe() != null) return;
        enc.setAnnuleLe(LocalDateTime.now());
        enc.setAnnulePar(auteur);
        enc.setMotifAnnulation(motif);
        encaissementPenaliteRepository.save(enc);
        lignePenaliteRepository.recalculerDepuisEncaissements(enc.getLignePenaliteId());
    }
}
