package com.tmk.vtcmanager.application.usecases.maintenance;

import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.maintenance.ReglementMaintenance;
import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.DetailMaintenance;
import com.tmk.vtcmanager.application.domain.operation.ElementMaintenance;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.SousCategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.application.domain.partenaire.FacturePartenaire;
import com.tmk.vtcmanager.application.domain.partenaire.Partenaire;
import com.tmk.vtcmanager.application.domain.partenaire.StatutFacturePartenaire;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.event.VehiculeStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import com.tmk.vtcmanager.application.ports.persistence.FacturePartenaireRepository;
import com.tmk.vtcmanager.application.ports.persistence.MaintenanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.ports.persistence.SousCategorieOperationRepository;
import com.tmk.vtcmanager.application.usecases.partenaire.EnregistrerFactureUseCase;
import com.tmk.vtcmanager.application.services.CompteTresorerieResolver;
import com.tmk.vtcmanager.application.services.PeriodeClotureeGuard;
import com.tmk.vtcmanager.application.services.RepartitionDetteMaintenanceService;
import com.tmk.vtcmanager.application.services.SequenceReferenceService;
import com.tmk.vtcmanager.application.services.CaisseClotureeGuard;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;

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
    private final FacturePartenaireRepository facturePartenaireRepository;
    private final EnregistrerFactureUseCase enregistrerFactureUseCase;
    private final RepartitionDetteMaintenanceService repartitionService;

    @Transactional
    public Maintenance execute(Long id, BigDecimal cout, LocalDate dateEffectuee,
                               ReglementMaintenance reglement, Long categorieId, Long sousCategorieId) {
        Maintenance maintenance = maintenanceRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Maintenance", id));

        periodeClotureeGuard.verifier(dateEffectuee);
        // À crédit, rien ne sort de la caisse : seule une intervention payée
        // comptant a besoin que la caisse du jour soit encore ouverte.
        if (!reglement.aCredit()) {
            caisseClotureeGuard.verifier(
                    compteTresorerieResolver.resoudre(null, reglement.modePaiementOuDefaut()),
                    dateEffectuee);
        }
        maintenance.terminer(cout, dateEffectuee);
        Maintenance saved = maintenanceRepository.save(maintenance);

        if (saved.getCout() != null && saved.getCout().compareTo(BigDecimal.ZERO) > 0) {
            String commentaire = String.format("Maintenance %s - %s",
                    saved.getType() != null ? saved.getType() : "AUTRE",
                    saved.getPartenaire() != null && saved.getPartenaire().getNom() != null
                            ? saved.getPartenaire().getNom() : "Prestataire non renseigné");

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

            if (reglement.aCredit()) {
                // Rien ne sort de la caisse : l'intervention reste due. La charge
                // est portée par la dette, à la date de l'intervention.
                genererDettes(saved, categorie, reglement.echeance(), commentaire);
            } else {
                DetailMaintenance operationDetail = buildDetailForOperation(saved.getDetailMaintenance());
                ModePaiement mode = reglement.modePaiementOuDefaut();

                OperationFinanciere operation = OperationFinanciere.builder()
                        .reference(sequenceReferenceService.suivante(
                                SequenceReferenceService.Journal.MAINTENANCE))
                        .typeOperation(TypeOperation.DEPENSE)
                        .dateOperation(saved.getDateEffectuee())
                        .montant(saved.getCout())
                        .commentaire(commentaire)
                        .vehicule(saved.getVehicule())
                        .statut(StatutOperation.PAYE)
                        .modePaiement(mode)
                        .compteTresorerieId(compteTresorerieResolver.resoudre(null, mode))
                        .categorie(categorie)
                        .sousCategorie(sousCategorie)
                        .detailMaintenance(operationDetail)
                        .maintenanceId(saved.getId())
                        // La dépense hérite du partenaire de l'intervention : la
                        // charge se lit ensuite par tiers, sans ressaisie.
                        .partenaire(saved.getPartenaire())
                        .build();

                operationRepository.save(operation);
            }
        }

        // Maintenance terminée → recalcul du statut du véhicule (sortie de EN_MAINTENANCE).
        if (saved.getVehicule() != null) {
            statutEventPublisher.publishStatutDirty(saved.getVehicule().getId());
        }

        return saved;
    }

    /**
     * Transforme l'intervention terminée en dettes envers ses partenaires.
     *
     * <p>Une dette par partenaire : le garage qui répare et le vendeur de pièces
     * sont deux créanciers distincts, chacun avec son échéance et son règlement.
     * Une ligne sans partenaire propre revient à celui de l'intervention — c'est
     * le cas courant, où un seul prestataire fait tout.
     *
     * <p>Le coût validé à la complétion fait foi : s'il s'écarte de la somme des
     * lignes (remise consentie, montant arrondi au moment de payer), l'écart est
     * porté par le partenaire principal, celui de l'intervention.
     */
    private void genererDettes(Maintenance maintenance, CategorieOperation categorie,
                               LocalDate echeance, String description) {
        boolean detteDejaOuverte = facturePartenaireRepository.findByMaintenanceId(maintenance.getId())
                .stream()
                .anyMatch(f -> f.getStatut() != StatutFacturePartenaire.ANNULEE);
        if (detteDejaOuverte) {
            throw new IllegalStateException(
                    "Cette intervention a déjà une dette : réglez-la ou annulez-la "
                            + "avant de terminer à nouveau la maintenance.");
        }

        Map<Long, BigDecimal> montantsParPartenaire = repartitionService.repartir(maintenance);

        for (Map.Entry<Long, BigDecimal> part : montantsParPartenaire.entrySet()) {
            if (part.getValue().signum() <= 0) continue;
            enregistrerFactureUseCase.executer(FacturePartenaire.builder()
                    .partenaire(Partenaire.builder().id(part.getKey()).build())
                    .categorie(categorie)
                    .vehicule(maintenance.getVehicule())
                    .dateFacture(maintenance.getDateEffectuee())
                    .dateEcheance(echeance)
                    .montant(part.getValue())
                    .maintenanceId(maintenance.getId())
                    .description(description)
                    .build());
        }
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