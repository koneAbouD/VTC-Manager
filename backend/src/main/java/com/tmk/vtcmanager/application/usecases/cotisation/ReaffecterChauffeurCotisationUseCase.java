package com.tmk.vtcmanager.application.usecases.cotisation;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import com.tmk.vtcmanager.application.domain.reaffectation.ReaffectationChauffeur;
import com.tmk.vtcmanager.application.exception.ChauffeurNotFoundException;
import com.tmk.vtcmanager.application.exception.LigneCotisationNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.ArreteCompteRepository;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.ports.persistence.ReaffectationChauffeurRepository;
import com.tmk.vtcmanager.application.ports.security.AuteurCourant;
import com.tmk.vtcmanager.application.services.NotificationReaffectationService;
import com.tmk.vtcmanager.application.services.ReaffectationChauffeurService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.transaction.annotation.Transactional;

import java.util.Objects;

/**
 * Porte une cotisation au compte d'un autre chauffeur.
 *
 * <p>Une cotisation n'est pas une dette comme les autres : encaissée, elle
 * devient un <b>dépôt détenu pour le compte du chauffeur</b>, que l'arrêté lui
 * rendra. En changer le titulaire, c'est donc déplacer un fonds — d'où le refus
 * catégorique dès qu'un arrêté y a touché, même partiellement : le décompte
 * nominatif est parti et l'argent a été versé.
 *
 * <p>Tant qu'aucun arrêté n'est passé, l'opération reste sans effet sur les
 * montants : la cotisation garde son nom, sa somme et son véhicule.
 *
 * <p>Cf. {@link com.tmk.vtcmanager.application.usecases.recette.ReaffecterChauffeurRecetteUseCase}
 * pour le verrou d'exécution et l'ordre vérifications-puis-écritures, communs
 * aux deux créances. Ici, pas de pénalité à emmener : rien ne s'adosse à une
 * cotisation.
 */
@Slf4j
@RequiredArgsConstructor
public class ReaffecterChauffeurCotisationUseCase {

    private final LigneCotisationRepository ligneCotisationRepository;
    private final ChauffeurRepository chauffeurRepository;
    private final ArreteCompteRepository arreteCompteRepository;
    private final OperationFinanciereRepository operationFinanciereRepository;
    private final ReaffectationChauffeurRepository reaffectationRepository;
    private final ReaffectationChauffeurService reaffectationService;
    private final NotificationReaffectationService notificationService;
    private final AuteurCourant auteurCourant;

    @Transactional
    public LigneCotisation executer(Long ligneId, Long chauffeurCibleId, String motif) {
        LigneCotisation ligne = ligneCotisationRepository.findById(ligneId)
                .orElseThrow(() -> new LigneCotisationNotFoundException(ligneId));

        if (chauffeurCibleId == null) {
            throw new IllegalArgumentException("Le chauffeur à qui porter la cotisation est obligatoire.");
        }
        if (Objects.equals(ligne.getChauffeurId(), chauffeurCibleId)) {
            return ligne;
        }
        if (motif == null || motif.isBlank()) {
            throw new IllegalArgumentException(
                    "Le motif de la réaffectation est obligatoire : un dépôt qui change de"
                            + " titulaire doit pouvoir s'expliquer.");
        }
        Chauffeur cible = chauffeurRepository.findById(chauffeurCibleId)
                .orElseThrow(() -> new ChauffeurNotFoundException(chauffeurCibleId));

        arreteCompteRepository.verrouillerExecution();

        reaffectationService.verifierLigne(ligne);
        reaffectationService.verifierChauffeurCible(
                ReaffectationChauffeurService.Cible.de(ligne), chauffeurCibleId);

        Long ancienChauffeurId = ligne.getChauffeurId();
        String ancienNom = ligne.getChauffeurNom();
        String auteur = auteurCourant.nom();

        ligneCotisationRepository.reaffecterChauffeur(ligneId, chauffeurCibleId);
        // Un versement a un seul payeur : si l'une de ses créances change de
        // débiteur, ses écritures ne décrivent plus le même billet.
        operationFinanciereRepository.detacherVersementsDesEncaissements(
                TypeDocumentCreance.COTISATION, ligneId);
        int operations = operationFinanciereRepository.reaffecterChauffeurDesEncaissements(
                TypeDocumentCreance.COTISATION, ligneId, chauffeurCibleId, auteur);

        reaffectationRepository.save(ReaffectationChauffeur.builder()
                .document(TypeDocumentCreance.COTISATION)
                .documentId(ligneId)
                .vehiculeId(ligne.getVehiculeId())
                .dateDocument(ligne.getDateCotisation())
                .ancienChauffeurId(ancienChauffeurId)
                .nouveauChauffeurId(chauffeurCibleId)
                .motif(motif.trim())
                .operationsReprises(operations)
                .createdBy(auteur)
                .build());

        log.info("Cotisation {} réaffectée : chauffeur {} → {} ({} écriture(s)) par {}",
                ligneId, ancienChauffeurId, chauffeurCibleId, operations, auteur);

        LigneCotisation rechargee = ligneCotisationRepository.findById(ligneId)
                .orElseThrow(() -> new LigneCotisationNotFoundException(ligneId));

        notificationService.ligneReaffectee(TypeDocumentCreance.COTISATION, ligneId,
                rechargee.getDateCotisation(), rechargee.getVehiculeImmatriculation(),
                rechargee.montantRestant(), ancienChauffeurId, ancienNom,
                chauffeurCibleId, nomComplet(cible));

        return rechargee;
    }

    private static String nomComplet(Chauffeur chauffeur) {
        String prenom = chauffeur.getPrenom() != null ? chauffeur.getPrenom() : "";
        String nom = chauffeur.getNom() != null ? chauffeur.getNom() : "";
        String complet = (prenom + " " + nom).trim();
        return complet.isEmpty() ? null : complet;
    }
}
