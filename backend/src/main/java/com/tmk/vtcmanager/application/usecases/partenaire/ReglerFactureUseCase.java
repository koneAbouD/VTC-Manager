package com.tmk.vtcmanager.application.usecases.partenaire;

import com.tmk.vtcmanager.application.domain.partenaire.FacturePartenaire;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.FacturePartenaireRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.services.CaisseClotureeGuard;
import com.tmk.vtcmanager.application.services.CompteTresorerieResolver;
import com.tmk.vtcmanager.application.services.PeriodeClotureeGuard;
import com.tmk.vtcmanager.application.services.SequenceReferenceService;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Règlement, total ou partiel, d'une facture partenaire.
 *
 * <p>Le paiement ne crée aucune charge : elle a déjà été constatée à la
 * réception de la facture. Il ne fait que sortir l'argent de la caisse et
 * réduire la dette — l'écriture porte donc le lien vers la facture, qui évite
 * de compter la charge deux fois en base engagement.
 */
@RequiredArgsConstructor
public class ReglerFactureUseCase {

    private final FacturePartenaireRepository factureRepository;
    private final OperationFinanciereRepository operationRepository;
    private final CompteTresorerieResolver compteTresorerieResolver;
    private final PeriodeClotureeGuard periodeClotureeGuard;
    private final CaisseClotureeGuard caisseClotureeGuard;
    private final SequenceReferenceService sequenceReferenceService;

    @Transactional
    public FacturePartenaire executer(Long factureId, BigDecimal montant, ModePaiement modePaiement,
                                       Long compteTresorerieId, LocalDate datePaiement,
                                       String commentaire) {
        FacturePartenaire facture = factureRepository.findById(factureId)
                .orElseThrow(() -> ResourceNotFoundException.of("Facture partenaire", factureId));

        if (!facture.getStatut().estOuverte()) {
            throw new IllegalStateException("Cette facture n'est plus à payer ("
                    + facture.getStatut() + ").");
        }
        if (montant == null || montant.signum() <= 0) {
            throw new IllegalArgumentException("Le montant réglé doit être positif.");
        }
        BigDecimal restant = facture.restantDu();
        if (montant.compareTo(restant) > 0) {
            throw new IllegalArgumentException("Le règlement dépasse le restant dû ("
                    + restant.toPlainString() + ").");
        }

        LocalDate date = datePaiement != null ? datePaiement : LocalDate.now();
        ModePaiement mode = modePaiement != null ? modePaiement : ModePaiement.ESPECES;
        Long compteId = compteTresorerieResolver.resoudre(compteTresorerieId, mode);

        periodeClotureeGuard.verifier(date);
        caisseClotureeGuard.verifier(compteId, date);

        operationRepository.save(OperationFinanciere.builder()
                .reference(sequenceReferenceService.suivante(
                        SequenceReferenceService.Journal.REGLEMENT_PARTENAIRE, date))
                .typeOperation(TypeOperation.DEPENSE)
                .categorie(facture.getCategorie())
                .vehicule(facture.getVehicule())
                .montant(montant)
                .modePaiement(mode)
                .compteTresorerieId(compteId)
                .dateOperation(date)
                // Date métier : celle de la facture, pour rattacher le règlement
                // à la charge qu'il solde.
                .dateReference(facture.getDateFacture())
                .statut(StatutOperation.PAYE)
                .facturePartenaireId(facture.getId())
                .commentaire(commentaire != null && !commentaire.isBlank()
                        ? commentaire
                        : "Règlement " + facture.getReference() + " — "
                                + facture.getPartenaire().getNom())
                .build());

        facture.setMontantPaye(facture.getMontantPaye().add(montant));
        facture.recalculerStatut();
        return factureRepository.save(facture);
    }
}
