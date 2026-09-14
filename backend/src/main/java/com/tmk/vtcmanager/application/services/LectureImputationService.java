package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.cotisation.EncaissementCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.penalite.EncaissementPenalite;
import com.tmk.vtcmanager.application.domain.penalite.LignePenalite;
import com.tmk.vtcmanager.application.domain.recette.Encaissement;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.versement.ImputationVersement;
import com.tmk.vtcmanager.application.domain.versement.NatureImputation;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementPenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import lombok.RequiredArgsConstructor;

import java.math.BigDecimal;
import java.util.Optional;

/**
 * Lit une écriture d'encaissement du côté de la créance qu'elle solde : quelle
 * nature, quelle ligne, ce qu'il y reste à devoir, sous quelle référence le
 * paiement a été reçu.
 *
 * <p>L'écriture ne connaît pas la ligne qui l'a produite ; l'encaissement, si.
 * On sonde donc les trois tables par identifiant d'écriture — comme le fait
 * l'annulation — sans rien déduire du code de catégorie. La pièce de caisse et
 * le reçu PDF lisent ainsi les écritures de la même façon.
 */
@RequiredArgsConstructor
public class LectureImputationService {

    private final EncaissementRepository encaissementRepository;
    private final EncaissementCotisationRepository encaissementCotisationRepository;
    private final EncaissementPenaliteRepository encaissementPenaliteRepository;
    private final LigneRecetteRepository ligneRecetteRepository;
    private final LigneCotisationRepository ligneCotisationRepository;
    private final LignePenaliteRepository lignePenaliteRepository;

    public ImputationVersement lire(OperationFinanciere op) {
        boolean annulee = op.estExtournee() || op.getStatut() == StatutOperation.ANNULEE;

        Optional<Encaissement> recette = encaissementRepository.findByOperationFinanciereId(op.getId());
        if (recette.isPresent()) {
            Long ligneId = recette.get().getLigneRecetteId();
            LigneRecette ligne = ligneRecetteRepository.findById(ligneId).orElse(null);
            return new ImputationVersement(op.getId(), op.getReference(), NatureImputation.RECETTE,
                    "Recette", ligneId, op.getDateReference(), op.getMontant(), annulee,
                    resteRecette(ligne), recette.get().getReference());
        }

        Optional<EncaissementCotisation> cotisation =
                encaissementCotisationRepository.findByOperationFinanciereId(op.getId());
        if (cotisation.isPresent()) {
            Long ligneId = cotisation.get().getLigneCotisationId();
            LigneCotisation ligne = ligneCotisationRepository.findById(ligneId).orElse(null);
            String libelle = ligne != null && ligne.getNomCotisation() != null
                    ? ligne.getNomCotisation() : "Cotisation";
            return new ImputationVersement(op.getId(), op.getReference(), NatureImputation.COTISATION,
                    libelle, ligneId, op.getDateReference(), op.getMontant(), annulee,
                    ligne == null ? null : ligne.montantRestant(), cotisation.get().getReference());
        }

        Optional<EncaissementPenalite> penalite =
                encaissementPenaliteRepository.findByOperationFinanciereId(op.getId());
        if (penalite.isPresent()) {
            Long ligneId = penalite.get().getLignePenaliteId();
            LignePenalite ligne = lignePenaliteRepository.findById(ligneId).orElse(null);
            // Le motif dit au chauffeur de quoi il s'acquitte : une pénalité seule
            // ne se reconnaît pas d'une autre.
            String libelle = ligne != null && ligne.getTypePenalite() != null
                    ? "Pénalité (" + minusculeInitiale(ligne.getTypePenalite().label) + ")"
                    : "Pénalité";
            return new ImputationVersement(op.getId(), op.getReference(), NatureImputation.PENALITE,
                    libelle, ligneId, op.getDateReference(), op.getMontant(), annulee,
                    ligne == null ? null : ligne.montantRestant(), penalite.get().getReference());
        }

        // Écriture dont l'encaissement a disparu (donnée héritée) : montrée telle
        // quelle, sans prétendre savoir ce qu'elle solde.
        return new ImputationVersement(op.getId(), op.getReference(), null,
                op.getCategorie() == null ? null : op.getCategorie().getLibelle(),
                null, op.getDateReference(), op.getMontant(), annulee, null, null);
    }

    /** Nul pour une recette au montant réel : elle n'a pas de dû d'avance. */
    private static BigDecimal resteRecette(LigneRecette ligne) {
        if (ligne == null || ligne.getMontantAttendu() == null) return null;
        BigDecimal encaisse = ligne.getMontantEncaisse() != null
                ? ligne.getMontantEncaisse() : BigDecimal.ZERO;
        return ligne.getMontantAttendu().subtract(encaisse).max(BigDecimal.ZERO);
    }

    private static String minusculeInitiale(String texte) {
        if (texte == null || texte.isEmpty()) return texte;
        return Character.toLowerCase(texte.charAt(0)) + texte.substring(1);
    }
}
