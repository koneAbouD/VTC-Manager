package com.tmk.vtcmanager.application.usecases.recette;

import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import com.tmk.vtcmanager.application.domain.modification.ModificationMontant;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.exception.LigneRecetteNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.ArreteCompteRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.ModificationMontantRepository;
import com.tmk.vtcmanager.application.ports.security.AuteurCourant;
import com.tmk.vtcmanager.application.services.ModificationMontantService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;

/**
 * Corrige ce que le chauffeur devait verser ce jour-là.
 *
 * <p>Les versements ne bougent pas : seul le montant attendu change, et le
 * statut se relit sur ce qui a été encaissé — une recette soldée redevient
 * partielle si l'on monte le montant, une recette partielle peut se trouver
 * soldée si on le baisse. La correction est consignée avec son motif.
 */
@Slf4j
@RequiredArgsConstructor
public class ModifierMontantAttenduRecetteUseCase {

    private final LigneRecetteRepository ligneRecetteRepository;
    private final ArreteCompteRepository arreteCompteRepository;
    private final ModificationMontantRepository modificationMontantRepository;
    private final ModificationMontantService modificationMontantService;
    private final AuteurCourant auteurCourant;

    @Transactional
    public LigneRecette executer(Long ligneId, BigDecimal nouveauMontant, String motif) {
        if (motif == null || motif.isBlank()) {
            throw new IllegalArgumentException("Le motif de la correction est obligatoire.");
        }
        // Un arrêté qui compense la recette pendant qu'on change son montant
        // l'éteindrait sur l'ancienne valeur.
        arreteCompteRepository.verrouillerExecution();

        LigneRecette ligne = ligneRecetteRepository.findById(ligneId)
                .orElseThrow(() -> new LigneRecetteNotFoundException(ligneId));
        BigDecimal ancien = ligne.getMontantAttendu();
        if (ancien != null && nouveauMontant != null && ancien.compareTo(nouveauMontant) == 0) {
            return ligne;
        }

        String blocage = modificationMontantService.motifBlocage(ligne);
        if (blocage != null) throw new IllegalStateException(blocage);
        modificationMontantService.verifierMontant(nouveauMontant, ligne.getMontantEncaisse());

        ligneRecetteRepository.modifierMontantAttendu(ligneId, nouveauMontant);
        ligneRecetteRepository.recalculerDepuisEncaissements(ligneId);
        String auteur = auteurCourant.nom();
        modificationMontantRepository.enregistrer(ModificationMontant.builder()
                .document(TypeDocumentCreance.RECETTE)
                .documentId(ligneId)
                .ancienMontant(ancien)
                .nouveauMontant(nouveauMontant)
                .motif(motif.trim())
                .createdBy(auteur)
                .build());
        log.info("Recette {} : montant attendu {} → {} par {}", ligneId, ancien, nouveauMontant, auteur);

        return ligneRecetteRepository.findById(ligneId)
                .orElseThrow(() -> new LigneRecetteNotFoundException(ligneId));
    }
}
