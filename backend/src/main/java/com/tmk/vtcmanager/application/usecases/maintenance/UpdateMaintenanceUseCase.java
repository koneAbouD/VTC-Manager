package com.tmk.vtcmanager.application.usecases.maintenance;

import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.DetailMaintenance;
import com.tmk.vtcmanager.application.services.SynchronisationDetteMaintenanceService;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.event.VehiculeStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import com.tmk.vtcmanager.application.ports.persistence.MaintenanceRepository;
import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@RequiredArgsConstructor
public class UpdateMaintenanceUseCase {

    private final MaintenanceRepository maintenanceRepository;
    private final CategorieOperationRepository categorieOperationRepository;
    private final VehiculeStatutEventPublisher statutEventPublisher;
    private final SynchronisationDetteMaintenanceService synchronisationDetteService;

    @Transactional
    public Maintenance execute(Long id, Maintenance data) {
        validerType(data.getType());

        Maintenance existing = maintenanceRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Maintenance", id));

        // Une intervention terminée ne se retouche plus : sa complétion a
        // produit une dépense — ou une dette envers le prestataire — dont le
        // montant et la date font foi. Les corriger ici les désaccorderait de
        // l'écriture qui, elle, est déjà au journal. Pour reprendre une
        // intervention, on annule la dépense : la maintenance repasse en
        // planifiée et peut être terminée de nouveau avec les bonnes valeurs.
        if (existing.getStatut() == MaintenanceStatus.TERMINEE) {
            throw new IllegalStateException("Cette maintenance est terminée : elle ne se modifie"
                    + " plus. Annulez la dépense qu'elle a générée — la maintenance repasse en"
                    + " planifiée — puis terminez-la de nouveau.");
        }

        existing.setType(data.getType());
        existing.setDatePrevue(data.getDatePrevue());
        // Coût et date d'exécution sont posés à la clôture, pas dans ce
        // formulaire : une requête qui n'en parle pas ne doit pas les effacer.
        if (data.getDateEffectuee() != null) existing.setDateEffectuee(data.getDateEffectuee());
        existing.setDescription(data.getDescription());
        existing.setKilometrageAuMoment(data.getKilometrageAuMoment());
        existing.setKilometrageProchaine(data.getKilometrageProchaine());
        if (data.getCout() != null) existing.setCout(data.getCout());
        existing.setPartenaire(data.getPartenaire());
        // Les éléments font partie de l'intervention : sans cette ligne, une
        // ligne ajoutée ou déplacée d'un prestataire à l'autre était perdue.
        existing.setDetailMaintenance(fusionnerDetail(existing, data));
        if (data.getStatut() != null) existing.setStatut(data.getStatut());
        Maintenance saved = maintenanceRepository.save(existing);

        // Ce qui vient de changer doit se voir tout de suite dans l'échéancier :
        // un coût corrigé ou une ligne déplacée change ce que l'on doit, et à qui.
        synchronisationDetteService.synchroniser(saved);

        // Le statut de la maintenance a pu changer (EN_COURS / TERMINEE / ANNULEE)
        // → recalcul du statut du véhicule.
        if (existing.getVehicule() != null) {
            statutEventPublisher.publishStatutDirty(existing.getVehicule().getId());
        }
        return saved;
    }

    /**
     * Détail à persister. Le détail existant garde son identité — ses lignes
     * sont remplacées, pas la ligne de détail elle-même — pour que la relation
     * survive à la mise à jour. Une requête sans détail ne touche à rien : elle
     * ne dit pas « plus d'éléments », elle ne parle pas des éléments.
     */
    private DetailMaintenance fusionnerDetail(Maintenance existing, Maintenance data) {
        DetailMaintenance entrant = data.getDetailMaintenance();
        if (entrant == null) return existing.getDetailMaintenance();

        // Détail vidé : l'intervention n'a plus de lignes, le détail s'efface.
        if (entrant.getElements() == null || entrant.getElements().isEmpty()) return null;

        DetailMaintenance actuel = existing.getDetailMaintenance();
        if (actuel != null) entrant.setId(actuel.getId());
        return entrant;
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
