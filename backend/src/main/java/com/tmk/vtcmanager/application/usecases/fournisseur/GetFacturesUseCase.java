package com.tmk.vtcmanager.application.usecases.fournisseur;

import com.tmk.vtcmanager.application.domain.fournisseur.FactureFournisseur;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.ports.persistence.FactureFournisseurRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;

/** Consultation des factures : par période, et échéancier des impayées. */
@RequiredArgsConstructor
public class GetFacturesUseCase {

    private final FactureFournisseurRepository factureRepository;
    private final OperationFinanciereRepository operationRepository;

    @Transactional(readOnly = true)
    public FactureFournisseur parId(Long id) {
        return factureRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Facture fournisseur", id));
    }

    /**
     * Règlements déjà passés sur la facture, du plus ancien au plus récent :
     * c'est l'historique qui explique le restant dû.
     */
    @Transactional(readOnly = true)
    public List<OperationFinanciere> reglements(Long factureId) {
        return operationRepository.findByFactureFournisseurId(factureId);
    }

    @Transactional(readOnly = true)
    public List<FactureFournisseur> parPeriode(int annee, int mois) {
        YearMonth periode = YearMonth.of(annee, mois);
        return factureRepository.findByPeriode(periode.atDay(1), periode.atEndOfMonth());
    }

    /**
     * Échéancier : ce qui reste à payer, de l'échéance la plus ancienne à la
     * plus récente — donc les retards en tête.
     */
    @Transactional(readOnly = true)
    public List<FactureFournisseur> echeancier(Long fournisseurId) {
        return factureRepository.findOuvertes(fournisseurId);
    }

    @Transactional(readOnly = true)
    public List<FactureFournisseur> enRetard(LocalDate date) {
        LocalDate reference = date != null ? date : LocalDate.now();
        return factureRepository.findOuvertes(null).stream()
                .filter(f -> f.estEnRetard(reference))
                .toList();
    }
}
