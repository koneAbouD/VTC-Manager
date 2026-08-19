package com.tmk.vtcmanager.application.usecases.tresorerie;

import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.application.domain.tresorerie.ClotureCaisse;
import com.tmk.vtcmanager.application.domain.tresorerie.CompteAvecSolde;
import com.tmk.vtcmanager.application.domain.tresorerie.StatutImputationEcart;
import com.tmk.vtcmanager.application.domain.tresorerie.TypeCompteTresorerie;
import com.tmk.vtcmanager.application.exception.ClotureCaisseDejaEffectueeException;
import com.tmk.vtcmanager.application.exception.CompteTresorerieNotFoundException;
import com.tmk.vtcmanager.application.exception.MotifEcartObligatoireException;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import com.tmk.vtcmanager.application.ports.persistence.ClotureCaisseRepository;
import com.tmk.vtcmanager.application.ports.persistence.CompteTresorerieRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.ports.security.AuteurCourant;
import com.tmk.vtcmanager.application.services.PeriodeClotureeGuard;
import com.tmk.vtcmanager.application.services.SequenceReferenceService;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;

@RequiredArgsConstructor
public class CloturerCaisseUseCase {

    /** Catégories d'attente : l'écart y dort jusqu'à sa décision d'imputation. */
    private static final String CODE_ATTENTE_MANQUANT = "ECART_CAISSE_ATTENTE_MANQUANT";
    private static final String CODE_ATTENTE_EXCEDENT = "ECART_CAISSE_ATTENTE_EXCEDENT";

    private final CompteTresorerieRepository compteTresorerieRepository;
    private final ClotureCaisseRepository clotureCaisseRepository;
    private final OperationFinanciereRepository operationFinanciereRepository;
    private final CategorieOperationRepository categorieOperationRepository;
    private final SequenceReferenceService sequenceReferenceService;
    private final PeriodeClotureeGuard periodeClotureeGuard;
    private final AuteurCourant auteurCourant;

    /**
     * Clôture le compte à une date : compare le solde théorique <em>arrêté à
     * cette date</em> au comptage physique et, en cas d'écart, crée l'opération
     * d'ajustement (motif obligatoire) qui réaligne le solde sur le comptage.
     *
     * <p>La date est libre — une caisse oubliée la veille reste régularisable —
     * mais jamais future, jamais dans une période comptable close, et toujours
     * postérieure au dernier comptage du compte : la série des comptages reste
     * ainsi chronologique.
     */
    @Transactional
    public ClotureCaisse executer(Long compteId, LocalDate dateCloture, BigDecimal soldeCompte,
                                  String motifEcart, String responsable) {
        LocalDate date = dateCloture != null ? dateCloture : LocalDate.now();
        if (date.isAfter(LocalDate.now())) {
            throw new IllegalArgumentException("Une caisse ne se compte pas à l'avance : "
                    + "la date de clôture ne peut pas être future.");
        }
        periodeClotureeGuard.verifier(date);

        if (clotureCaisseRepository.existsByCompteIdAndDateCloture(compteId, date)) {
            throw new ClotureCaisseDejaEffectueeException(date);
        }
        clotureCaisseRepository.findDerniereDateCloture(compteId).ifPresent(derniere -> {
            if (!date.isAfter(derniere)) {
                throw new IllegalArgumentException("Ce compte a déjà été clôturé le " + derniere
                        + " : on ne recompte pas une journée antérieure.");
            }
        });

        CompteAvecSolde compte = compteTresorerieRepository.findAvecSoldeALaDate(compteId, date)
                .orElseThrow(() -> new CompteTresorerieNotFoundException(compteId));

        BigDecimal theorique = compte.getSolde();
        BigDecimal ecart = soldeCompte.subtract(theorique);
        boolean avecEcart = ecart.compareTo(BigDecimal.ZERO) != 0;

        Long operationId = null;
        if (avecEcart) {
            if (motifEcart == null || motifEcart.isBlank()) {
                throw new MotifEcartObligatoireException(theorique, soldeCompte, ecart);
            }
            operationId = creerOperationAjustement(compte, ecart, motifEcart, date).getId();
        }

        ClotureCaisse cloture = ClotureCaisse.builder()
                .compteId(compteId)
                .dateCloture(date)
                .soldeTheorique(theorique)
                .soldeCompte(soldeCompte)
                .ecart(ecart)
                .motifEcart(motifEcart)
                .operationId(operationId)
                .responsable(responsable != null && !responsable.isBlank()
                        ? responsable : auteurCourant.nom())
                // Sans écart, il n'y a rien à imputer.
                .imputationStatut(avecEcart ? StatutImputationEcart.EN_ATTENTE : null)
                .build();
        return clotureCaisseRepository.save(cloture);
    }

    /**
     * Ajustement en compte d'attente : il réaligne le solde sur le comptage —
     * la trésorerie, elle, est constatée — sans toucher au résultat, qui attend
     * la décision d'imputation.
     */
    private OperationFinanciere creerOperationAjustement(CompteAvecSolde compte, BigDecimal ecart,
                                                         String motif, LocalDate date) {
        boolean excedent = ecart.compareTo(BigDecimal.ZERO) > 0;
        CategorieOperation categorie = categorieOperationRepository
                .findByCode(excedent ? CODE_ATTENTE_EXCEDENT : CODE_ATTENTE_MANQUANT).orElse(null);

        TypeCompteTresorerie type = compte.getCompte().getType();
        OperationFinanciere operation = OperationFinanciere.builder()
                .typeOperation(excedent ? TypeOperation.REVENU : TypeOperation.DEPENSE)
                .categorie(categorie)
                .montant(ecart.abs())
                .modePaiement(type == TypeCompteTresorerie.MOBILE_MONEY
                        ? ModePaiement.MOBILE_MONEY : ModePaiement.ESPECES)
                .compteTresorerieId(compte.getCompte().getId())
                .dateOperation(date)
                .commentaire("Clôture de caisse — " + motif)
                .reference(sequenceReferenceService.suivante(
                        SequenceReferenceService.Journal.CLOTURE, date))
                .statut(excedent ? StatutOperation.ENCAISSE : StatutOperation.PAYE)
                .build();
        return operationFinanciereRepository.save(operation);
    }
}
