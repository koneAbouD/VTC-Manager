package com.tmk.vtcmanager.application.usecases.maintenance;

import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import com.tmk.vtcmanager.application.domain.maintenance.ReglementMaintenance;
import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.DetailMaintenance;
import com.tmk.vtcmanager.application.domain.operation.ElementMaintenance;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.SousCategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.application.domain.partenaire.Partenaire;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.exception.PeriodeClotureeException;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.exception.VehiculeNotFoundException;
import com.tmk.vtcmanager.application.ports.event.VehiculeStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import com.tmk.vtcmanager.application.ports.persistence.FacturePartenaireRepository;
import com.tmk.vtcmanager.application.ports.persistence.MaintenanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.ports.persistence.SousCategorieOperationRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import com.tmk.vtcmanager.application.services.CaisseClotureeGuard;
import com.tmk.vtcmanager.application.services.CaisseCreditriceGuard;
import com.tmk.vtcmanager.application.services.CompteTresorerieResolver;
import com.tmk.vtcmanager.application.services.PeriodeClotureeGuard;
import com.tmk.vtcmanager.application.services.RepartitionDetteMaintenanceService;
import com.tmk.vtcmanager.application.services.SequenceReferenceService;
import com.tmk.vtcmanager.application.usecases.partenaire.EnregistrerFactureUseCase;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

/**
 * Cycle de vie d'une intervention : planification, complétion au comptant et
 * annulation. Chaque transition touche l'état du parc — une voiture à l'atelier
 * ne doit pas apparaître disponible — d'où le recalcul systématique du statut
 * du véhicule.
 *
 * <p>Le volet « à payer » (dettes partenaires) est couvert par
 * {@code CompleteMaintenanceDetteTest}.</p>
 */
class CycleMaintenanceUseCasesTest {

    private static final Long MAINTENANCE_ID = 300L;
    private static final Long VEHICULE_ID = 5L;
    private static final LocalDate HIER = LocalDate.now().minusDays(1);

    private MaintenanceRepository maintenanceRepository;
    private OperationFinanciereRepository operationRepository;
    private CategorieOperationRepository categorieRepository;
    private SousCategorieOperationRepository sousCategorieRepository;
    private VehiculeStatutEventPublisher statutEventPublisher;
    private CompteTresorerieResolver compteTresorerieResolver;
    private PeriodeClotureeGuard periodeClotureeGuard;
    private SequenceReferenceService sequenceReferenceService;
    private CaisseClotureeGuard caisseClotureeGuard;
    private CaisseCreditriceGuard caisseCreditriceGuard;
    private FacturePartenaireRepository facturePartenaireRepository;
    private EnregistrerFactureUseCase enregistrerFactureUseCase;
    private RepartitionDetteMaintenanceService repartitionService;
    private VehiculeRepository vehiculeRepository;
    private CompleteMaintenanceUseCase completeUseCase;
    private AnnulerMaintenanceUseCase annulerUseCase;
    private ScheduleMaintenanceUseCase scheduleUseCase;

    @BeforeEach
    void setUp() {
        maintenanceRepository = mock(MaintenanceRepository.class);
        operationRepository = mock(OperationFinanciereRepository.class);
        categorieRepository = mock(CategorieOperationRepository.class);
        sousCategorieRepository = mock(SousCategorieOperationRepository.class);
        statutEventPublisher = mock(VehiculeStatutEventPublisher.class);
        compteTresorerieResolver = mock(CompteTresorerieResolver.class);
        periodeClotureeGuard = mock(PeriodeClotureeGuard.class);
        sequenceReferenceService = mock(SequenceReferenceService.class);
        caisseClotureeGuard = mock(CaisseClotureeGuard.class);
        caisseCreditriceGuard = mock(CaisseCreditriceGuard.class);
        facturePartenaireRepository = mock(FacturePartenaireRepository.class);
        enregistrerFactureUseCase = mock(EnregistrerFactureUseCase.class);
        repartitionService = mock(RepartitionDetteMaintenanceService.class);
        vehiculeRepository = mock(VehiculeRepository.class);

        when(maintenanceRepository.save(any())).thenAnswer(inv -> {
            Maintenance m = inv.getArgument(0);
            if (m.getId() == null) m.setId(MAINTENANCE_ID);
            return m;
        });
        when(operationRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(categorieRepository.findByCode(any())).thenReturn(Optional.empty());
        when(categorieRepository.findById(anyLong())).thenReturn(Optional.empty());
        when(sousCategorieRepository.findByCategorieId(anyLong())).thenReturn(Optional.empty());
        when(sousCategorieRepository.findById(anyLong())).thenReturn(Optional.empty());
        when(compteTresorerieResolver.resoudre(any(), any())).thenReturn(1L);
        when(sequenceReferenceService.suivante(any())).thenReturn("MNT-2026-000005");
        when(vehiculeRepository.findById(VEHICULE_ID))
                .thenReturn(Optional.of(Vehicule.builder().id(VEHICULE_ID).build()));
        when(categorieRepository.findBySousCategorieLibelle("Maintenances"))
                .thenReturn(List.of(CategorieOperation.builder().id(3L).code("VIDANGE").build()));

        completeUseCase = new CompleteMaintenanceUseCase(maintenanceRepository, operationRepository,
                categorieRepository, sousCategorieRepository, statutEventPublisher,
                compteTresorerieResolver, periodeClotureeGuard, sequenceReferenceService,
                caisseClotureeGuard, caisseCreditriceGuard, facturePartenaireRepository,
                enregistrerFactureUseCase, repartitionService);
        annulerUseCase = new AnnulerMaintenanceUseCase(maintenanceRepository, statutEventPublisher);
        scheduleUseCase = new ScheduleMaintenanceUseCase(maintenanceRepository, vehiculeRepository,
                categorieRepository, statutEventPublisher, completeUseCase);
    }

    private Maintenance maintenance(MaintenanceStatus statut) {
        return Maintenance.builder()
                .id(MAINTENANCE_ID).type("VIDANGE").statut(statut)
                .datePrevue(HIER)
                .vehicule(Vehicule.builder().id(VEHICULE_ID).build())
                .build();
    }

    private OperationFinanciere depenseEnregistree() {
        ArgumentCaptor<OperationFinanciere> capture =
                ArgumentCaptor.forClass(OperationFinanciere.class);
        verify(operationRepository).save(capture.capture());
        return capture.getValue();
    }

    @Nested
    @DisplayName("Complétion au comptant")
    class Completion {

        @Test
        @DisplayName("L'intervention terminée génère une dépense payée du montant validé")
        void depense_generee() {
            when(maintenanceRepository.findById(MAINTENANCE_ID))
                    .thenReturn(Optional.of(maintenance(MaintenanceStatus.EN_COURS)));

            Maintenance terminee = completeUseCase.execute(MAINTENANCE_ID,
                    BigDecimal.valueOf(85_000), HIER,
                    ReglementMaintenance.comptant(ModePaiement.ESPECES), null, null);

            assertThat(terminee.getStatut()).isEqualTo(MaintenanceStatus.TERMINEE);
            assertThat(terminee.getDateEffectuee()).isEqualTo(HIER);

            OperationFinanciere depense = depenseEnregistree();
            assertThat(depense.getTypeOperation()).isEqualTo(TypeOperation.DEPENSE);
            assertThat(depense.getStatut()).isEqualTo(StatutOperation.PAYE);
            assertThat(depense.getMontant()).isEqualByComparingTo("85000");
            assertThat(depense.getReference()).isEqualTo("MNT-2026-000005");
            assertThat(depense.getMaintenanceId()).isEqualTo(MAINTENANCE_ID);
            assertThat(depense.getDateOperation()).isEqualTo(HIER);
        }

        @Test
        @DisplayName("Le libellé cite le type et, s'il existe, le prestataire")
        void libelle_avec_prestataire() {
            Maintenance avecPartenaire = maintenance(MaintenanceStatus.EN_COURS);
            avecPartenaire.setPartenaire(Partenaire.builder().id(2L).nom("Garage Central").build());
            when(maintenanceRepository.findById(MAINTENANCE_ID)).thenReturn(Optional.of(avecPartenaire));

            completeUseCase.execute(MAINTENANCE_ID, BigDecimal.valueOf(85_000), HIER,
                    ReglementMaintenance.comptant(null), null, null);

            OperationFinanciere depense = depenseEnregistree();
            assertThat(depense.getCommentaire()).isEqualTo("Maintenance VIDANGE - Garage Central");
            // La charge se lit ensuite par tiers, sans ressaisie.
            assertThat(depense.getPartenaire().getNom()).isEqualTo("Garage Central");
        }

        @Test
        @DisplayName("Sans prestataire, le libellé s'arrête au type")
        void libelle_sans_prestataire() {
            when(maintenanceRepository.findById(MAINTENANCE_ID))
                    .thenReturn(Optional.of(maintenance(MaintenanceStatus.EN_COURS)));

            completeUseCase.execute(MAINTENANCE_ID, BigDecimal.valueOf(85_000), HIER,
                    ReglementMaintenance.comptant(null), null, null);

            assertThat(depenseEnregistree().getCommentaire()).isEqualTo("Maintenance VIDANGE");
        }

        @Test
        @DisplayName("À défaut de catégorie fournie, celle du type de maintenance est retenue")
        void categorie_deduite_du_type() {
            when(maintenanceRepository.findById(MAINTENANCE_ID))
                    .thenReturn(Optional.of(maintenance(MaintenanceStatus.EN_COURS)));
            when(categorieRepository.findByCode("VIDANGE"))
                    .thenReturn(Optional.of(CategorieOperation.builder().id(7L).code("VIDANGE").build()));

            completeUseCase.execute(MAINTENANCE_ID, BigDecimal.valueOf(85_000), HIER,
                    ReglementMaintenance.comptant(null), null, null);

            assertThat(depenseEnregistree().getCategorie().getCode()).isEqualTo("VIDANGE");
        }

        @Test
        @DisplayName("Aucune dépense ne reste sans catégorie : repli sur Réparation")
        void categorie_de_repli() {
            when(maintenanceRepository.findById(MAINTENANCE_ID))
                    .thenReturn(Optional.of(maintenance(MaintenanceStatus.EN_COURS)));
            when(categorieRepository.findByCode("REPARATION"))
                    .thenReturn(Optional.of(CategorieOperation.builder().id(9L).code("REPARATION").build()));

            completeUseCase.execute(MAINTENANCE_ID, BigDecimal.valueOf(85_000), HIER,
                    ReglementMaintenance.comptant(null), null, null);

            // Sans ce repli, la dépense retomberait dans la bulle « Autres ».
            assertThat(depenseEnregistree().getCategorie().getCode()).isEqualTo("REPARATION");
        }

        @Test
        @DisplayName("La sous-catégorie est résolue depuis la catégorie retenue")
        void sous_categorie_resolue() {
            when(maintenanceRepository.findById(MAINTENANCE_ID))
                    .thenReturn(Optional.of(maintenance(MaintenanceStatus.EN_COURS)));
            when(categorieRepository.findByCode("VIDANGE"))
                    .thenReturn(Optional.of(CategorieOperation.builder().id(7L).code("VIDANGE").build()));
            when(sousCategorieRepository.findByCategorieId(7L)).thenReturn(Optional.of(
                    SousCategorieOperation.builder().id(11L).libelle("Maintenances").build()));

            completeUseCase.execute(MAINTENANCE_ID, BigDecimal.valueOf(85_000), HIER,
                    ReglementMaintenance.comptant(null), null, null);

            assertThat(depenseEnregistree().getSousCategorie().getLibelle()).isEqualTo("Maintenances");
        }

        @Test
        @DisplayName("Le détail des pièces est recopié sur la dépense")
        void detail_recopie() {
            Maintenance avecDetail = maintenance(MaintenanceStatus.EN_COURS);
            avecDetail.setDetailMaintenance(DetailMaintenance.builder()
                    .id(1L)
                    .elements(new ArrayList<>(List.of(
                            ElementMaintenance.builder().libelle("Filtre")
                                    .montant(BigDecimal.valueOf(15_000)).build())))
                    .build());
            when(maintenanceRepository.findById(MAINTENANCE_ID)).thenReturn(Optional.of(avecDetail));

            completeUseCase.execute(MAINTENANCE_ID, BigDecimal.valueOf(85_000), HIER,
                    ReglementMaintenance.comptant(null), null, null);

            DetailMaintenance detail = depenseEnregistree().getDetailMaintenance();
            assertThat(detail.getElements()).singleElement()
                    .extracting(ElementMaintenance::getLibelle).isEqualTo("Filtre");
            // Copie, pas la même instance : la dépense ne doit pas partager
            // l'entité détail de la maintenance.
            assertThat(detail.getId()).isNull();
        }

        @Test
        @DisplayName("Une intervention à coût nul ne génère aucune dépense")
        void cout_nul() {
            when(maintenanceRepository.findById(MAINTENANCE_ID))
                    .thenReturn(Optional.of(maintenance(MaintenanceStatus.EN_COURS)));

            completeUseCase.execute(MAINTENANCE_ID, BigDecimal.ZERO, HIER,
                    ReglementMaintenance.comptant(null), null, null);

            verify(operationRepository, never()).save(any());
        }

        @Test
        @DisplayName("Le véhicule sort de l'atelier : son statut est recalculé")
        void statut_vehicule_recalcule() {
            when(maintenanceRepository.findById(MAINTENANCE_ID))
                    .thenReturn(Optional.of(maintenance(MaintenanceStatus.EN_COURS)));

            completeUseCase.execute(MAINTENANCE_ID, BigDecimal.valueOf(85_000), HIER,
                    ReglementMaintenance.comptant(null), null, null);

            verify(statutEventPublisher).publishStatutDirty(VEHICULE_ID);
        }

        @Test
        @DisplayName("Une complétion dans une période close est refusée")
        void periode_close() {
            when(maintenanceRepository.findById(MAINTENANCE_ID))
                    .thenReturn(Optional.of(maintenance(MaintenanceStatus.EN_COURS)));
            doThrow(new PeriodeClotureeException(HIER)).when(periodeClotureeGuard).verifier(HIER);

            assertThatThrownBy(() -> completeUseCase.execute(MAINTENANCE_ID,
                    BigDecimal.valueOf(85_000), HIER, ReglementMaintenance.comptant(null), null, null))
                    .isInstanceOf(PeriodeClotureeException.class);
            verify(maintenanceRepository, never()).save(any());
        }

        @Test
        @DisplayName("Le comptant est contrôlé contre le solde de la caisse")
        void controle_du_solde() {
            when(maintenanceRepository.findById(MAINTENANCE_ID))
                    .thenReturn(Optional.of(maintenance(MaintenanceStatus.EN_COURS)));

            completeUseCase.execute(MAINTENANCE_ID, BigDecimal.valueOf(85_000), HIER,
                    ReglementMaintenance.comptant(ModePaiement.ESPECES), null, null);

            verify(caisseClotureeGuard).verifier(1L, HIER);
            verify(caisseCreditriceGuard).verifier(1L, BigDecimal.valueOf(85_000), HIER);
        }

        @Test
        @DisplayName("Une maintenance inexistante est refusée")
        void maintenance_introuvable() {
            when(maintenanceRepository.findById(MAINTENANCE_ID)).thenReturn(Optional.empty());

            assertThatThrownBy(() -> completeUseCase.execute(MAINTENANCE_ID,
                    BigDecimal.valueOf(85_000), HIER, ReglementMaintenance.comptant(null), null, null))
                    .isInstanceOf(ResourceNotFoundException.class);
        }
    }

    @Nested
    @DisplayName("Annulation")
    class Annulation {

        @Test
        @DisplayName("Une maintenance annulée libère le véhicule")
        void annulation_nominale() {
            when(maintenanceRepository.findById(MAINTENANCE_ID))
                    .thenReturn(Optional.of(maintenance(MaintenanceStatus.EN_COURS)));

            Maintenance annulee = annulerUseCase.execute(MAINTENANCE_ID);

            assertThat(annulee.getStatut()).isEqualTo(MaintenanceStatus.ANNULEE);
            verify(statutEventPublisher).publishStatutDirty(VEHICULE_ID);
        }

        @Test
        @DisplayName("Une maintenance déjà annulée est refusée")
        void deja_annulee() {
            when(maintenanceRepository.findById(MAINTENANCE_ID))
                    .thenReturn(Optional.of(maintenance(MaintenanceStatus.ANNULEE)));

            assertThatThrownBy(() -> annulerUseCase.execute(MAINTENANCE_ID))
                    .isInstanceOf(IllegalStateException.class)
                    .hasMessageContaining("déjà annulée");
            verifyNoInteractions(statutEventPublisher);
        }

        @Test
        @DisplayName("Une maintenance inexistante est refusée")
        void introuvable() {
            when(maintenanceRepository.findById(MAINTENANCE_ID)).thenReturn(Optional.empty());

            assertThatThrownBy(() -> annulerUseCase.execute(MAINTENANCE_ID))
                    .isInstanceOf(ResourceNotFoundException.class);
        }
    }

    @Nested
    @DisplayName("Planification")
    class Planification {

        private Maintenance aPlanifier(LocalDate datePrevue) {
            return Maintenance.builder()
                    .type("VIDANGE").datePrevue(datePrevue).description("Vidange 10 000 km")
                    .build();
        }

        @Test
        @DisplayName("Une maintenance future est enregistrée et rattachée au véhicule")
        void planification_future() {
            LocalDate demain = LocalDate.now().plusDays(1);

            Maintenance saved = scheduleUseCase.execute(VEHICULE_ID, aPlanifier(demain));

            assertThat(saved.getVehicule().getId()).isEqualTo(VEHICULE_ID);
            assertThat(saved.getDatePrevue()).isEqualTo(demain);
            verify(statutEventPublisher).publishStatutDirty(VEHICULE_ID);
        }

        @Test
        @DisplayName("La date de prochaine maintenance du véhicule est mise à jour")
        void prochaine_maintenance_vehicule() {
            scheduleUseCase.execute(VEHICULE_ID, aPlanifier(LocalDate.now().plusDays(1)));

            verify(vehiculeRepository).save(any(Vehicule.class));
        }

        @Test
        @DisplayName("Un type de maintenance inconnu est refusé")
        void type_invalide() {
            Maintenance invalide = aPlanifier(LocalDate.now().plusDays(1));
            invalide.setType("LAVAGE_A_SEC");

            assertThatThrownBy(() -> scheduleUseCase.execute(VEHICULE_ID, invalide))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessageContaining("Type de maintenance invalide");
            verify(maintenanceRepository, never()).save(any());
        }

        @Test
        @DisplayName("Un type absent n'est pas contrôlé")
        void type_absent() {
            Maintenance sansType = aPlanifier(LocalDate.now().plusDays(1));
            sansType.setType(null);

            scheduleUseCase.execute(VEHICULE_ID, sansType);

            verify(maintenanceRepository).save(any());
        }

        @Test
        @DisplayName("Un véhicule inexistant est refusé")
        void vehicule_introuvable() {
            when(vehiculeRepository.findById(VEHICULE_ID)).thenReturn(Optional.empty());

            assertThatThrownBy(() -> scheduleUseCase.execute(
                    VEHICULE_ID, aPlanifier(LocalDate.now().plusDays(1))))
                    .isInstanceOf(VehiculeNotFoundException.class);
        }

        @Test
        @DisplayName("Un détail sans aucune ligne n'est pas enregistré")
        void detail_vide_ignore() {
            Maintenance avecDetailVide = aPlanifier(LocalDate.now().plusDays(1));
            avecDetailVide.setDetailMaintenance(
                    DetailMaintenance.builder().elements(new ArrayList<>()).build());

            assertThat(scheduleUseCase.execute(VEHICULE_ID, avecDetailVide)
                    .getDetailMaintenance()).isNull();
        }

        @Test
        @DisplayName("Une intervention datée d'hier est réputée déjà réalisée et terminée d'office")
        void date_passee_termine_immediatement() {
            when(maintenanceRepository.findById(MAINTENANCE_ID))
                    .thenReturn(Optional.of(maintenance(MaintenanceStatus.EN_COURS)));
            Maintenance rattrapage = aPlanifier(HIER);
            rattrapage.setDetailMaintenance(DetailMaintenance.builder()
                    .elements(new ArrayList<>(List.of(
                            ElementMaintenance.builder().libelle("Huile")
                                    .montant(BigDecimal.valueOf(20_000)).build(),
                            ElementMaintenance.builder().libelle("Filtre")
                                    .montant(BigDecimal.valueOf(5_000)).build())))
                    .build());

            Maintenance resultat = scheduleUseCase.execute(VEHICULE_ID, rattrapage);

            assertThat(resultat.getStatut()).isEqualTo(MaintenanceStatus.TERMINEE);
            // Le montant est la somme des éléments saisis.
            assertThat(depenseEnregistree().getMontant()).isEqualByComparingTo("25000");
        }
    }
}
