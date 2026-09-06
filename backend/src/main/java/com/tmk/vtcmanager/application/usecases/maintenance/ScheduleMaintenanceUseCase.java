package com.tmk.vtcmanager.application.usecases.maintenance;

import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.maintenance.ReglementMaintenance;
import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.DetailMaintenance;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.exception.VehiculeNotFoundException;
import com.tmk.vtcmanager.application.ports.event.VehiculeStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import com.tmk.vtcmanager.application.ports.persistence.MaintenanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/**
 * Planification (création) d'une maintenance pour un véhicule.
 * Valide que le type fourni correspond à une catégorie de la sous-catégorie "Maintenances".
 * Met également à jour la date de prochaine maintenance du véhicule si plus proche.
 *
 * <p>Si la date prévue est déjà passée, la maintenance est considérée comme
 * réalisée : elle est immédiatement terminée (date effectuée = date prévue) et
 * l'opération de dépense associée est générée automatiquement. Le coût et le
 * règlement de cette clôture viennent de la saisie quand le client les fournit
 * — il les demande à l'exploitant au moment d'enregistrer l'intervention.</p>
 */
@RequiredArgsConstructor
public class ScheduleMaintenanceUseCase {

    private final MaintenanceRepository maintenanceRepository;
    private final VehiculeRepository vehiculeRepository;
    private final CategorieOperationRepository categorieOperationRepository;
    private final VehiculeStatutEventPublisher statutEventPublisher;
    private final CompleteMaintenanceUseCase completeMaintenanceUseCase;

    /**
     * Planification sans précision de règlement : une intervention déjà passée
     * est réputée réglée sur place. Chemin des planifications automatiques
     * (vidanges dues), qui n'ont personne à interroger.
     */
    @Transactional
    public Maintenance execute(Long vehiculeId, Maintenance maintenance) {
        return execute(vehiculeId, maintenance, ReglementMaintenance.comptant(null));
    }

    @Transactional
    public Maintenance execute(Long vehiculeId, Maintenance maintenance,
                               ReglementMaintenance reglement) {
        validerType(maintenance.getType());

        if (vehiculeId != null) {
            Vehicule vehicule = vehiculeRepository.findById(vehiculeId)
                    .orElseThrow(() -> new VehiculeNotFoundException(vehiculeId));
            maintenance.setVehicule(vehicule);

            if (maintenance.getDatePrevue() != null) {
                vehicule.updateProchaineMaintenance(maintenance.getDatePrevue());
                vehiculeRepository.save(vehicule);
            }
        }

        // Un détail sans ligne n'a rien à enregistrer.
        DetailMaintenance detail = maintenance.getDetailMaintenance();
        if (detail != null && (detail.getElements() == null || detail.getElements().isEmpty())) {
            maintenance.setDetailMaintenance(null);
        }

        maintenance.initializeDefaults();
        Maintenance saved = maintenanceRepository.save(maintenance);

        // Date prévue déjà passée → maintenance réputée réalisée : on la termine
        // à la date prévue et on génère automatiquement l'écriture — dépense
        // payée, ou dette envers les prestataires si l'intervention reste due.
        LocalDate datePrevue = saved.getDatePrevue();
        if (datePrevue != null && datePrevue.isBefore(LocalDate.now())) {
            return completeMaintenanceUseCase.execute(saved.getId(), coutDeCloture(saved), datePrevue,
                    reglement != null ? reglement : ReglementMaintenance.comptant(null), null, null);
        }

        // Recalcul du statut (→ EN_MAINTENANCE si la maintenance est créée EN_COURS).
        statutEventPublisher.publishStatutDirty(vehiculeId);
        return saved;
    }

    /**
     * Coût retenu pour la clôture d'office. Le montant saisi fait foi dès qu'il
     * est transmis — c'est le coût réel, constaté après coup, qui peut s'écarter
     * des lignes prévues. À défaut, la somme des éléments de l'intervention.
     */
    private BigDecimal coutDeCloture(Maintenance maintenance) {
        BigDecimal saisi = maintenance.getCout();
        return saisi != null ? saisi : sommeElements(maintenance);
    }

    /** Somme des montants des éléments de la maintenance (0 si aucun). */
    private BigDecimal sommeElements(Maintenance maintenance) {
        DetailMaintenance detail = maintenance.getDetailMaintenance();
        return detail != null ? detail.montantTotal() : BigDecimal.ZERO;
    }

    private void validerType(String type) {
        if (type == null || type.isBlank()) return;
        List<CategorieOperation> typesValides =
                categorieOperationRepository.findBySousCategorieLibelle("Maintenances");
        boolean valide = typesValides.stream()
                .anyMatch(c -> c.getCode().equals(type));
        if (!valide) {
            List<String> codes = typesValides.stream()
                    .map(CategorieOperation::getCode)
                    .toList();
            throw new IllegalArgumentException(
                    "Type de maintenance invalide : '" + type + "'. Types disponibles : " + codes);
        }
    }
}
