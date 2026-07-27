package com.tmk.vtcmanager.application.usecases.maintenance;

import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.DetailMaintenance;
import com.tmk.vtcmanager.application.domain.operation.ElementMaintenance;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.SousCategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.event.VehiculeStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import com.tmk.vtcmanager.application.ports.persistence.MaintenanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.ports.persistence.SousCategorieOperationRepository;
import com.tmk.vtcmanager.application.services.CompteTresorerieResolver;
import com.tmk.vtcmanager.application.services.PeriodeClotureeGuard;
import com.tmk.vtcmanager.application.services.SequenceReferenceService;
import com.tmk.vtcmanager.application.services.CaisseClotureeGuard;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.List;

@RequiredArgsConstructor
public class CompleteMaintenanceUseCase {

    /** Catégorie de dépense par défaut si le type de maintenance n'est pas
     *  résolu en catégorie (garantit qu'aucune dépense ne reste sans catégorie
     *  — évite la bulle « Autres » de la répartition). */
    private static final String CODE_CATEGORIE_MAINTENANCE_DEFAUT = "REPARATION";

    private final MaintenanceRepository maintenanceRepository;
    private final OperationFinanciereRepository operationRepository;
    private final CategorieOperationRepository categorieRepository;
    private final SousCategorieOperationRepository sousCategorieRepository;
    private final VehiculeStatutEventPublisher statutEventPublisher;
    private final CompteTresorerieResolver compteTresorerieResolver;
    private final PeriodeClotureeGuard periodeClotureeGuard;
    private final SequenceReferenceService sequenceReferenceService;
    private final CaisseClotureeGuard caisseClotureeGuard;

    @Transactional
    public Maintenance execute(Long id, BigDecimal cout, LocalDate dateEffectuee,
                               ModePaiement modePaiement, Long categorieId, Long sousCategorieId) {
        Maintenance maintenance = maintenanceRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Maintenance", id));

        periodeClotureeGuard.verifier(dateEffectuee);
        caisseClotureeGuard.verifier(
                compteTresorerieResolver.resoudre(null,
                        modePaiement != null ? modePaiement : ModePaiement.ESPECES),
                dateEffectuee);
        maintenance.terminer(cout, dateEffectuee);
        Maintenance saved = maintenanceRepository.save(maintenance);

        if (saved.getCout() != null && saved.getCout().compareTo(BigDecimal.ZERO) > 0) {
            String commentaire = String.format("Maintenance %s - %s",
                    saved.getType() != null ? saved.getType() : "AUTRE",
                    saved.getPrestataire() != null ? saved.getPrestataire() : "Prestataire non renseigné");

String reference = sequenceReferenceService.suivante(
                    SequenceReferenceService.Journal.MAINTENANCE);

            CategorieOperation categorie = categorieId != null
                    ? categorieRepository.findById(categorieId).orElse(null)
                    : saved.getCategorieType();

            // Repli : ne jamais créer une dépense sans catégorie (bulle « Autres »).
            // 1) déduire la catégorie du type de maintenance (VIDANGE, PEINTURE…),
            // 2) à défaut, une catégorie maintenance générique (Réparation).
            if (categorie == null && saved.getType() != null && !saved.getType().isBlank()) {
                categorie = categorieRepository.findByCode(saved.getType()).orElse(null);
            }
            if (categorie == null) {
                categorie = categorieRepository.findByCode(CODE_CATEGORIE_MAINTENANCE_DEFAUT).orElse(null);
            }

            // La sous-catégorie n'est jamais chargée avec la catégorie
            // (CategorieOperationPersistenceMapper l'ignore) : on la résout via le
            // repository (relation 1-1) pour que le filtre « Maintenances » la retrouve.
            SousCategorieOperation sousCategorie = sousCategorieId != null
                    ? sousCategorieRepository.findById(sousCategorieId).orElse(null)
                    : (categorie != null && categorie.getId() != null
                            ? sousCategorieRepository.findByCategorieId(categorie.getId()).orElse(null)
                            : null);

            DetailMaintenance operationDetail = buildDetailForOperation(saved.getDetailMaintenance());

            OperationFinanciere operation = OperationFinanciere.builder()
                    .reference(reference)
                    .typeOperation(TypeOperation.DEPENSE)
                    .dateOperation(saved.getDateEffectuee())
                    .montant(saved.getCout())
                    .commentaire(commentaire)
                    .vehicule(saved.getVehicule())
                    .statut(StatutOperation.PAYE)
                    .modePaiement(modePaiement != null ? modePaiement : ModePaiement.ESPECES)
                    .compteTresorerieId(compteTresorerieResolver.resoudre(null,
                            modePaiement != null ? modePaiement : ModePaiement.ESPECES))
                    .categorie(categorie)
                    .sousCategorie(sousCategorie)
                    .detailMaintenance(operationDetail)
                    .maintenanceId(saved.getId())
                    .build();

            operationRepository.save(operation);
        }

        // Maintenance terminée → recalcul du statut du véhicule (sortie de EN_MAINTENANCE).
        if (saved.getVehicule() != null) {
            statutEventPublisher.publishStatutDirty(saved.getVehicule().getId());
        }

        return saved;
    }

    private DetailMaintenance buildDetailForOperation(DetailMaintenance source) {
        if (source == null || source.getElements() == null || source.getElements().isEmpty()) return null;
        List<ElementMaintenance> copies = source.getElements().stream()
                .map(e -> ElementMaintenance.builder()
                        .catalogueElement(e.getCatalogueElement())
                        .libelle(e.getLibelle())
                        .montant(e.getMontant())
                        .build())
                .toList();
        return DetailMaintenance.builder().elements(copies).build();
    }
}