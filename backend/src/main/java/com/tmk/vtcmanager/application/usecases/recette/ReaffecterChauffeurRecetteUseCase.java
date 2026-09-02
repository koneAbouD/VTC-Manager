package com.tmk.vtcmanager.application.usecases.recette;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import com.tmk.vtcmanager.application.domain.penalite.LignePenalite;
import com.tmk.vtcmanager.application.domain.reaffectation.ReaffectationChauffeur;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.exception.ChauffeurNotFoundException;
import com.tmk.vtcmanager.application.exception.LigneRecetteNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.ArreteCompteRepository;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.ports.persistence.ReaffectationChauffeurRepository;
import com.tmk.vtcmanager.application.ports.security.AuteurCourant;
import com.tmk.vtcmanager.application.services.NotificationReaffectationService;
import com.tmk.vtcmanager.application.services.ReaffectationChauffeurService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.Objects;

/**
 * Porte une recette au compte d'un autre chauffeur.
 *
 * <p>Rien ne change du montant, du véhicule ni du statut : la recette reste
 * celle de cette voiture, ce jour-là, pour cette somme. Seul le débiteur
 * change — et avec lui tout ce qui a copié son identité au moment de
 * l'écriture : les opérations d'encaissement, et la pénalité de recette non
 * versée qu'elle a pu engendrer.
 *
 * <p>Deux gestes de prudence encadrent l'opération. Le <b>verrou d'exécution
 * des arrêtés</b> d'abord : une créance ouverte n'est marquée nulle part comme
 * « en cours d'arrêté », et un arrêté qui la compense pendant qu'on la déplace
 * l'imputerait au mauvais compte. Toutes les <b>vérifications ensuite, avant
 * la moindre écriture</b> : une pénalité déjà encaissée doit faire échouer la
 * réaffectation entière, pas la laisser à moitié faite.
 */
@Slf4j
@RequiredArgsConstructor
public class ReaffecterChauffeurRecetteUseCase {

    private final LigneRecetteRepository ligneRecetteRepository;
    private final ChauffeurRepository chauffeurRepository;
    private final ArreteCompteRepository arreteCompteRepository;
    private final OperationFinanciereRepository operationFinanciereRepository;
    private final LignePenaliteRepository lignePenaliteRepository;
    private final ReaffectationChauffeurRepository reaffectationRepository;
    private final ReaffectationChauffeurService reaffectationService;
    private final NotificationReaffectationService notificationService;
    private final AuteurCourant auteurCourant;

    @Transactional
    public LigneRecette executer(Long ligneId, Long chauffeurCibleId, String motif) {
        LigneRecette ligne = ligneRecetteRepository.findById(ligneId)
                .orElseThrow(() -> new LigneRecetteNotFoundException(ligneId));

        if (chauffeurCibleId == null) {
            throw new IllegalArgumentException("Le chauffeur à qui porter la recette est obligatoire.");
        }
        // Rien à faire, et rien à consigner : ce n'est pas une erreur de
        // confirmer le chauffeur déjà en place.
        if (Objects.equals(ligne.getChauffeurId(), chauffeurCibleId)) {
            return ligne;
        }
        if (motif == null || motif.isBlank()) {
            throw new IllegalArgumentException(
                    "Le motif de la réaffectation est obligatoire : une créance qui change de"
                            + " débiteur doit pouvoir s'expliquer.");
        }
        Chauffeur cible = chauffeurRepository.findById(chauffeurCibleId)
                .orElseThrow(() -> new ChauffeurNotFoundException(chauffeurCibleId));

        // Sérialise avec les arrêtés de compte, jusqu'à la fin de la transaction.
        arreteCompteRepository.verrouillerExecution();

        // ── Tout ce qui peut refuser, avant toute écriture ──────────────────
        reaffectationService.verifierLigne(ligne);
        reaffectationService.verifierChauffeurCible(
                ReaffectationChauffeurService.Cible.de(ligne), chauffeurCibleId);
        // Le refus des pénalités déjà appliquées appartient à verifierLigne :
        // il ferme la ligne pour tout le monde, et la fiche doit le savoir avant
        // d'offrir l'action. Ici, il ne reste qu'à ramasser celles qui suivent.
        List<LignePenalite> penalitesASuivre = reaffectationService.penalitesQuiSuivent(ligneId);

        // ── Écritures ──────────────────────────────────────────────────────
        Long ancienChauffeurId = ligne.getChauffeurId();
        String ancienNom = ligne.getChauffeurNom();
        String auteur = auteurCourant.nom();

        ligneRecetteRepository.reaffecterChauffeur(ligneId, chauffeurCibleId);
        int operations = operationFinanciereRepository.reaffecterChauffeurDesEncaissements(
                TypeDocumentCreance.RECETTE, ligneId, chauffeurCibleId, auteur);
        penalitesASuivre.forEach(p ->
                lignePenaliteRepository.reaffecterChauffeur(p.getId(), chauffeurCibleId));

        reaffectationRepository.save(ReaffectationChauffeur.builder()
                .document(TypeDocumentCreance.RECETTE)
                .documentId(ligneId)
                .vehiculeId(ligne.getVehiculeId())
                .dateDocument(ligne.getDateRecette())
                .ancienChauffeurId(ancienChauffeurId)
                .nouveauChauffeurId(chauffeurCibleId)
                .motif(motif.trim())
                .operationsReprises(operations)
                .penalitesReprises(penalitesASuivre.size())
                .createdBy(auteur)
                .build());

        log.info("Recette {} réaffectée : chauffeur {} → {} ({} écriture(s), {} pénalité(s)) par {}",
                ligneId, ancienChauffeurId, chauffeurCibleId, operations, penalitesASuivre.size(), auteur);

        LigneRecette rechargee = ligneRecetteRepository.findById(ligneId)
                .orElseThrow(() -> new LigneRecetteNotFoundException(ligneId));

        notificationService.ligneReaffectee(TypeDocumentCreance.RECETTE, ligneId,
                rechargee.getDateRecette(), rechargee.getVehiculeImmatriculation(),
                montantRestant(rechargee), ancienChauffeurId, ancienNom,
                chauffeurCibleId, nomComplet(cible));

        return rechargee;
    }

    /**
     * Ce qu'il reste à devoir sur la ligne. Nul quand la recette est à montant
     * réel : il n'y a alors pas de plafond, donc pas de reste chiffrable.
     */
    private static BigDecimal montantRestant(LigneRecette ligne) {
        if (ligne.getMontantAttendu() == null) return null;
        BigDecimal encaisse = ligne.getMontantEncaisse() != null
                ? ligne.getMontantEncaisse() : BigDecimal.ZERO;
        return ligne.getMontantAttendu().subtract(encaisse).max(BigDecimal.ZERO);
    }

    private static String nomComplet(Chauffeur chauffeur) {
        String prenom = chauffeur.getPrenom() != null ? chauffeur.getPrenom() : "";
        String nom = chauffeur.getNom() != null ? chauffeur.getNom() : "";
        String complet = (prenom + " " + nom).trim();
        return complet.isEmpty() ? null : complet;
    }
}
