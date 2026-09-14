package com.tmk.vtcmanager.application.usecases.versement;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.cotisation.EncaissementCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.recette.Encaissement;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.domain.versement.ImputationVersement;
import com.tmk.vtcmanager.application.domain.versement.NatureImputation;
import com.tmk.vtcmanager.application.domain.versement.Versement;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import lombok.RequiredArgsConstructor;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Lit une pièce de caisse : ses écritures, et pour chacune la créance qu'elle
 * solde avec ce qu'il y reste à devoir.
 *
 * <p>Le reste dû ne se lit pas sur l'écriture — elle ne connaît pas la ligne
 * qui l'a produite. Il se retrouve par l'encaissement, qui la connaît : c'est
 * ce qui permet au reçu d'un versement de dire ce que le chauffeur doit encore.
 */
@RequiredArgsConstructor
public class GetVersementUseCase {

    private final OperationFinanciereRepository operationFinanciereRepository;
    private final EncaissementRepository encaissementRepository;
    private final EncaissementCotisationRepository encaissementCotisationRepository;
    private final LigneRecetteRepository ligneRecetteRepository;
    private final LigneCotisationRepository ligneCotisationRepository;

    public Versement executer(UUID versementId) {
        List<OperationFinanciere> ecritures = operationFinanciereRepository.findByVersementId(versementId);
        if (ecritures.isEmpty()) {
            throw new ResourceNotFoundException("Versement introuvable : " + versementId);
        }

        // Les écritures d'un versement partagent billet, jour et chauffeur —
        // c'est l'invariant que tiennent les corrections. La première suffit.
        OperationFinanciere tete = ecritures.get(0);
        Chauffeur chauffeur = tete.getChauffeur();
        Vehicule vehicule = tete.getVehicule();

        return new Versement(
                versementId,
                tete.getDateOperation(),
                tete.getModePaiement(),
                chauffeur == null ? null : chauffeur.getId(),
                nomComplet(chauffeur),
                chauffeur == null ? null : chauffeur.getTelephone(),
                vehicule == null ? null : vehicule.getId(),
                vehicule == null ? null : vehicule.getImmatriculation(),
                ecritures.stream().map(this::imputation).toList());
    }

    private ImputationVersement imputation(OperationFinanciere op) {
        boolean annulee = op.estExtournee() || op.getStatut() == StatutOperation.ANNULEE;

        Optional<Encaissement> recette = encaissementRepository.findByOperationFinanciereId(op.getId());
        if (recette.isPresent()) {
            Long ligneId = recette.get().getLigneRecetteId();
            LigneRecette ligne = ligneRecetteRepository.findById(ligneId).orElse(null);
            return new ImputationVersement(op.getId(), op.getReference(), NatureImputation.RECETTE,
                    "Recette", ligneId, op.getDateReference(), op.getMontant(), annulee,
                    resteRecette(ligne));
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
                    ligne == null ? null : ligne.montantRestant());
        }

        // Écriture rattachée dont l'encaissement a disparu (donnée héritée) :
        // montrée telle quelle, sans prétendre savoir ce qu'elle solde.
        return new ImputationVersement(op.getId(), op.getReference(), null,
                op.getCategorie() == null ? null : op.getCategorie().getLibelle(),
                null, op.getDateReference(), op.getMontant(), annulee, null);
    }

    /** Nul pour une recette au montant réel : elle n'a pas de dû d'avance. */
    private static BigDecimal resteRecette(LigneRecette ligne) {
        if (ligne == null || ligne.getMontantAttendu() == null) return null;
        BigDecimal encaisse = ligne.getMontantEncaisse() != null
                ? ligne.getMontantEncaisse() : BigDecimal.ZERO;
        return ligne.getMontantAttendu().subtract(encaisse).max(BigDecimal.ZERO);
    }

    private static String nomComplet(Chauffeur chauffeur) {
        if (chauffeur == null) return null;
        String prenom = chauffeur.getPrenom() != null ? chauffeur.getPrenom() : "";
        String nom = chauffeur.getNom() != null ? chauffeur.getNom() : "";
        String complet = (prenom + " " + nom).trim();
        return complet.isEmpty() ? null : complet;
    }
}
