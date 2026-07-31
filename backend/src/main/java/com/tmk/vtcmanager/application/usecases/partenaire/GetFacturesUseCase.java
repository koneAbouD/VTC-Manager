package com.tmk.vtcmanager.application.usecases.partenaire;

import com.tmk.vtcmanager.application.domain.partenaire.FacturePartenaire;
import com.tmk.vtcmanager.application.domain.partenaire.LigneDette;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.ports.persistence.FacturePartenaireRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;
import java.util.Map;

/** Consultation des factures : par période, et échéancier des impayées. */
@RequiredArgsConstructor
public class GetFacturesUseCase {

    private final FacturePartenaireRepository factureRepository;
    private final OperationFinanciereRepository operationRepository;

    @Transactional(readOnly = true)
    public FacturePartenaire parId(Long id) {
        FacturePartenaire facture = factureRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Facture partenaire", id));
        return avecLignes(List.of(facture)).getFirst();
    }

    /**
     * Règlements déjà passés sur la facture, du plus ancien au plus récent :
     * c'est l'historique qui explique le restant dû.
     */
    @Transactional(readOnly = true)
    public List<OperationFinanciere> reglements(Long factureId) {
        return operationRepository.findByFacturePartenaireId(factureId);
    }

    /** Dettes nées d'une intervention — ce que l'atelier a laissé à payer. */
    @Transactional(readOnly = true)
    public List<FacturePartenaire> parMaintenance(Long maintenanceId) {
        return avecLignes(factureRepository.findByMaintenanceId(maintenanceId));
    }

    @Transactional(readOnly = true)
    public List<FacturePartenaire> parPeriode(int annee, int mois) {
        YearMonth periode = YearMonth.of(annee, mois);
        return avecLignes(
                factureRepository.findByPeriode(periode.atDay(1), periode.atEndOfMonth()));
    }

    /**
     * Échéancier : ce qui reste à payer, de l'échéance la plus ancienne à la
     * plus récente — donc les retards en tête.
     */
    @Transactional(readOnly = true)
    public List<FacturePartenaire> echeancier(Long partenaireId) {
        return avecLignes(factureRepository.findOuvertes(partenaireId));
    }

    @Transactional(readOnly = true)
    public List<FacturePartenaire> enRetard(LocalDate date) {
        LocalDate reference = date != null ? date : LocalDate.now();
        return avecLignes(factureRepository.findOuvertes(null).stream()
                .filter(f -> f.estEnRetard(reference))
                .toList());
    }

    /**
     * Attache à chaque dette le détail de ce qu'elle paie. En une requête pour
     * toute la liste : un échéancier de cinquante dettes ne doit pas coûter
     * cinquante allers-retours.
     */
    private List<FacturePartenaire> avecLignes(List<FacturePartenaire> factures) {
        List<Long> ids = factures.stream()
                .map(FacturePartenaire::getId)
                .filter(java.util.Objects::nonNull)
                .toList();
        if (ids.isEmpty()) return factures;

        Map<Long, List<LigneDette>> lignes = factureRepository.lignesParFacture(ids);
        factures.forEach(f -> f.setLignes(lignes.getOrDefault(f.getId(), List.of())));
        return factures;
    }
}
