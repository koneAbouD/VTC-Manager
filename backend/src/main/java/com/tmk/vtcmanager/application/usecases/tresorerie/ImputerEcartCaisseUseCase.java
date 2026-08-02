package com.tmk.vtcmanager.application.usecases.tresorerie;

import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.application.domain.tresorerie.ClotureCaisse;
import com.tmk.vtcmanager.application.domain.tresorerie.StatutImputationEcart;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import com.tmk.vtcmanager.application.ports.persistence.ClotureCaisseRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.ports.security.AuteurCourant;
import com.tmk.vtcmanager.application.services.PeriodeClotureeGuard;
import com.tmk.vtcmanager.application.services.SequenceReferenceService;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * Décision sur un écart de caisse en attente.
 *
 * <p>Deux issues, et une seule écriture dans les deux cas — celle qui solde le
 * compte d'attente :
 * <ul>
 *   <li>{@code PERTE} : l'entreprise supporte le manquant (charge) ou conserve
 *       l'excédent (produit). L'écart entre alors dans le résultat, au mois de
 *       la décision.</li>
 *   <li>{@code RECOUVREE} : le responsable rembourse. Le compte d'attente est
 *       soldé sans passer par le résultat — la somme devient une créance sur
 *       lui. L'encaissement du remboursement se saisit ensuite avec la
 *       catégorie « Remboursement d'écart de caisse », hors résultat : c'est
 *       l'extinction de cette créance, pas un produit.</li>
 * </ul>
 *
 * <p>Aucune de ces écritures ne mouvemente le compte de trésorerie : la caisse a
 * déjà été réalignée sur le comptage au moment de la clôture. Leur rattacher un
 * compte reviendrait à faire entrer une seconde fois un argent qui n'a pas
 * bougé — et, en {@code RECOUVREE}, à encaisser le remboursement deux fois.
 */
@RequiredArgsConstructor
public class ImputerEcartCaisseUseCase {

    private static final String CODE_MANQUANT = "ECART_CAISSE_MANQUANT";
    private static final String CODE_EXCEDENT = "ECART_CAISSE_EXCEDENT";
    private static final String CODE_ATTENTE_MANQUANT = "ECART_CAISSE_ATTENTE_MANQUANT";
    private static final String CODE_ATTENTE_EXCEDENT = "ECART_CAISSE_ATTENTE_EXCEDENT";

    private final ClotureCaisseRepository clotureCaisseRepository;
    private final OperationFinanciereRepository operationFinanciereRepository;
    private final CategorieOperationRepository categorieOperationRepository;
    private final PeriodeClotureeGuard periodeClotureeGuard;
    private final SequenceReferenceService sequenceReferenceService;
    private final AuteurCourant auteurCourant;

    @Transactional
    public ClotureCaisse executer(Long clotureId, StatutImputationEcart decision, String motif) {
        if (decision != StatutImputationEcart.PERTE && decision != StatutImputationEcart.RECOUVREE) {
            throw new IllegalArgumentException(
                    "Décision attendue : PERTE (l'entreprise supporte) ou RECOUVREE (le responsable rembourse).");
        }
        if (motif == null || motif.isBlank()) {
            throw new IllegalArgumentException("Le motif de l'imputation est obligatoire.");
        }

        ClotureCaisse cloture = clotureCaisseRepository.findById(clotureId)
                .orElseThrow(() -> ResourceNotFoundException.of("Clôture de caisse", clotureId));
        if (!cloture.attendImputation()) {
            throw new IllegalStateException("Cet écart n'est pas en attente d'imputation.");
        }

        // Les deux écritures sont datées du **comptage**, pas de la décision :
        // le fait générateur de l'écart est la journée où la caisse a été
        // comptée. Les dater du jour de l'imputation ferait porter au mois
        // suivant un manquant né dans le mois précédent — la clôture exigeant
        // que l'écart soit tranché avant de figer, la décision tombe presque
        // toujours après la fin du mois compté.
        LocalDate date = cloture.getDateCloture();
        periodeClotureeGuard.verifier(date);
        // Pas de verrou de caisse ici : l'imputation ne mouvemente aucun compte
        // de trésorerie, elle ne peut donc pas faire mentir un comptage. L'exiger
        // interdirait au contraire d'imputer l'écart de la veille sur une caisse
        // comptée quotidiennement — alors que la clôture du mois réclame
        // justement qu'aucun écart ne reste en attente.

        boolean excedent = cloture.getEcart().compareTo(BigDecimal.ZERO) > 0;
        BigDecimal montant = cloture.getEcart().abs();

        // Solde du compte d'attente : écriture de sens inverse à l'ajustement.
        operationFinanciereRepository.save(ecritureSoldeAttente(cloture, excedent, montant, date, motif));

        Long operationImputationId = null;
        if (decision == StatutImputationEcart.PERTE) {
            // …et constatation en charge (manquant) ou en produit (excédent).
            operationImputationId = operationFinanciereRepository
                    .save(ecritureResultat(cloture, excedent, montant, date, motif)).getId();
        }

        cloture.setImputationStatut(decision);
        cloture.setImputationMotif(motif);
        cloture.setImputeeLe(LocalDateTime.now());
        cloture.setImputeePar(auteurCourant.nom());
        cloture.setOperationImputationId(operationImputationId);
        return clotureCaisseRepository.save(cloture);
    }

    /** Contre-passe l'attente : même catégorie d'attente, sens inverse. */
    private OperationFinanciere ecritureSoldeAttente(ClotureCaisse cloture, boolean excedent,
                                                     BigDecimal montant, LocalDate date, String motif) {
        CategorieOperation attente = categorie(excedent ? CODE_ATTENTE_EXCEDENT : CODE_ATTENTE_MANQUANT);
        return OperationFinanciere.builder()
                .typeOperation(excedent ? TypeOperation.DEPENSE : TypeOperation.REVENU)
                .categorie(attente)
                .montant(montant)
                // Sans compte de trésorerie : voir l'en-tête de classe.
                .dateOperation(date)
                .statut(excedent ? StatutOperation.PAYE : StatutOperation.ENCAISSE)
                .reference(sequenceReferenceService.suivante(
                        SequenceReferenceService.Journal.CLOTURE, date))
                .commentaire("Solde du compte d'attente — écart du "
                        + cloture.getDateCloture() + " — " + motif)
                .build();
    }

    /** Constate l'écart au résultat, dans le sens de l'ajustement d'origine. */
    private OperationFinanciere ecritureResultat(ClotureCaisse cloture, boolean excedent,
                                                 BigDecimal montant, LocalDate date, String motif) {
        CategorieOperation resultat = categorie(excedent ? CODE_EXCEDENT : CODE_MANQUANT);
        return OperationFinanciere.builder()
                .typeOperation(excedent ? TypeOperation.REVENU : TypeOperation.DEPENSE)
                .categorie(resultat)
                .montant(montant)
                // Sans compte de trésorerie : voir l'en-tête de classe.
                .dateOperation(date)
                .statut(excedent ? StatutOperation.ENCAISSE : StatutOperation.PAYE)
                .reference(sequenceReferenceService.suivante(
                        SequenceReferenceService.Journal.CLOTURE, date))
                .commentaire("Écart de caisse du " + cloture.getDateCloture()
                        + " imputé — responsable : " + cloture.getResponsable() + " — " + motif)
                .build();
    }

    private CategorieOperation categorie(String code) {
        return categorieOperationRepository.findByCode(code).orElse(null);
    }
}
