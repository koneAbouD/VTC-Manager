package com.tmk.vtcmanager.application.usecases.fournisseur;

import com.tmk.vtcmanager.application.domain.fournisseur.FactureFournisseur;
import com.tmk.vtcmanager.application.domain.fournisseur.StatutFactureFournisseur;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.FactureFournisseurRepository;
import com.tmk.vtcmanager.application.ports.persistence.FournisseurRepository;
import com.tmk.vtcmanager.application.services.PeriodeClotureeGuard;
import com.tmk.vtcmanager.application.services.SequenceReferenceService;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Réception d'une facture fournisseur.
 *
 * <p>C'est le moment où la charge naît, à la date de la facture — indépendamment
 * du jour où elle sera payée. La dette apparaît au passif dans la foulée.
 */
@RequiredArgsConstructor
public class EnregistrerFactureUseCase {

    private final FactureFournisseurRepository factureRepository;
    private final FournisseurRepository fournisseurRepository;
    private final PeriodeClotureeGuard periodeClotureeGuard;
    private final SequenceReferenceService sequenceReferenceService;

    @Transactional
    public FactureFournisseur executer(FactureFournisseur facture) {
        if (facture.getMontant() == null || facture.getMontant().signum() <= 0) {
            throw new IllegalArgumentException("Le montant de la facture doit être positif.");
        }
        Long fournisseurId = facture.getFournisseur() != null ? facture.getFournisseur().getId() : null;
        if (fournisseurId == null) {
            throw new IllegalArgumentException("La facture doit désigner un fournisseur.");
        }
        facture.setFournisseur(fournisseurRepository.findById(fournisseurId)
                .orElseThrow(() -> ResourceNotFoundException.of("Fournisseur", fournisseurId)));

        LocalDate dateFacture = facture.getDateFacture() != null
                ? facture.getDateFacture() : LocalDate.now();
        // La charge est datée de la facture : elle ne peut pas tomber dans un
        // mois dont les états sont déjà publiés.
        periodeClotureeGuard.verifier(dateFacture);

        facture.setId(null);
        facture.setDateFacture(dateFacture);
        // Sans échéance convenue, la facture est due à réception.
        facture.setDateEcheance(facture.getDateEcheance() != null
                ? facture.getDateEcheance() : dateFacture);
        facture.setMontantPaye(BigDecimal.ZERO);
        facture.setStatut(StatutFactureFournisseur.A_PAYER);
        facture.setReference(sequenceReferenceService.suivante(
                SequenceReferenceService.Journal.FOURNISSEUR, dateFacture));
        return factureRepository.save(facture);
    }
}
