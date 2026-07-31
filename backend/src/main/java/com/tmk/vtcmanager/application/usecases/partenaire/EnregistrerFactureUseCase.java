package com.tmk.vtcmanager.application.usecases.partenaire;

import com.tmk.vtcmanager.application.domain.partenaire.FacturePartenaire;
import com.tmk.vtcmanager.application.domain.partenaire.StatutFacturePartenaire;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.FacturePartenaireRepository;
import com.tmk.vtcmanager.application.ports.persistence.PartenaireRepository;
import com.tmk.vtcmanager.application.services.PeriodeClotureeGuard;
import com.tmk.vtcmanager.application.services.SequenceReferenceService;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Réception d'une facture partenaire.
 *
 * <p>C'est le moment où la charge naît, à la date de la facture — indépendamment
 * du jour où elle sera payée. La dette apparaît au passif dans la foulée.
 */
@RequiredArgsConstructor
public class EnregistrerFactureUseCase {

    private final FacturePartenaireRepository factureRepository;
    private final PartenaireRepository partenaireRepository;
    private final PeriodeClotureeGuard periodeClotureeGuard;
    private final SequenceReferenceService sequenceReferenceService;

    @Transactional
    public FacturePartenaire executer(FacturePartenaire facture) {
        if (facture.getMontant() == null || facture.getMontant().signum() <= 0) {
            throw new IllegalArgumentException("Le montant de la facture doit être positif.");
        }
        Long partenaireId = facture.getPartenaire() != null ? facture.getPartenaire().getId() : null;
        if (partenaireId == null) {
            throw new IllegalArgumentException("La facture doit désigner un partenaire.");
        }
        facture.setPartenaire(partenaireRepository.findById(partenaireId)
                .orElseThrow(() -> ResourceNotFoundException.of("Partenaire", partenaireId)));

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
        facture.setStatut(StatutFacturePartenaire.A_PAYER);
        facture.setReference(sequenceReferenceService.suivante(
                SequenceReferenceService.Journal.PARTENAIRE, dateFacture));
        return factureRepository.save(facture);
    }
}
