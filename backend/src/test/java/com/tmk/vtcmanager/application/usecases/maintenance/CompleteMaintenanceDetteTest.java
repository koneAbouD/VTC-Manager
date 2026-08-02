package com.tmk.vtcmanager.application.usecases.maintenance;

import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.maintenance.ReglementMaintenance;
import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.DetailMaintenance;
import com.tmk.vtcmanager.application.domain.operation.ElementMaintenance;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.partenaire.FacturePartenaire;
import com.tmk.vtcmanager.application.domain.partenaire.Partenaire;
import com.tmk.vtcmanager.application.domain.partenaire.StatutFacturePartenaire;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.ports.event.VehiculeStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import com.tmk.vtcmanager.application.ports.persistence.FacturePartenaireRepository;
import com.tmk.vtcmanager.application.ports.persistence.MaintenanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.ports.persistence.SousCategorieOperationRepository;
import com.tmk.vtcmanager.application.services.CaisseClotureeGuard;
import com.tmk.vtcmanager.application.services.CaisseCreditriceGuard;
import com.tmk.vtcmanager.application.services.CompteTresorerieResolver;
import com.tmk.vtcmanager.application.services.PeriodeClotureeGuard;
import com.tmk.vtcmanager.application.services.RepartitionDetteMaintenanceService;
import com.tmk.vtcmanager.application.services.SequenceReferenceService;
import com.tmk.vtcmanager.application.usecases.partenaire.EnregistrerFactureUseCase;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Une intervention terminée sans être réglée doit se voir dans le passif :
 * elle engendre une dette par partenaire, et aucune sortie de caisse.
 */
class CompleteMaintenanceDetteTest {

    private static final LocalDate LE_10_MARS = LocalDate.of(2026, 3, 10);
    private static final LocalDate FIN_MARS = LocalDate.of(2026, 3, 31);

    private MaintenanceRepository maintenanceRepository;
    private OperationFinanciereRepository operationRepository;
    private FacturePartenaireRepository facturePartenaireRepository;
    private EnregistrerFactureUseCase enregistrerFactureUseCase;
    private CompleteMaintenanceUseCase useCase;

    @BeforeEach
    void setUp() {
        maintenanceRepository = mock(MaintenanceRepository.class);
        operationRepository = mock(OperationFinanciereRepository.class);
        facturePartenaireRepository = mock(FacturePartenaireRepository.class);
        enregistrerFactureUseCase = mock(EnregistrerFactureUseCase.class);

        CategorieOperationRepository categorieRepository = mock(CategorieOperationRepository.class);
        when(categorieRepository.findByCode(any())).thenReturn(Optional.of(
                CategorieOperation.builder().id(7L).code("REPARATION").libelle("Réparation").build()));

        SousCategorieOperationRepository sousCategorieRepository =
                mock(SousCategorieOperationRepository.class);
        when(sousCategorieRepository.findByCategorieId(anyLong())).thenReturn(Optional.empty());

        CompteTresorerieResolver compteResolver = mock(CompteTresorerieResolver.class);
        when(compteResolver.resoudre(any(), any())).thenReturn(1L);

        SequenceReferenceService sequences = mock(SequenceReferenceService.class);
        when(sequences.suivante(any())).thenReturn("MNT-2026-000001");

        when(maintenanceRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(facturePartenaireRepository.findByMaintenanceId(anyLong())).thenReturn(List.of());

        useCase = new CompleteMaintenanceUseCase(
                maintenanceRepository, operationRepository, categorieRepository,
                sousCategorieRepository, mock(VehiculeStatutEventPublisher.class), compteResolver,
                mock(PeriodeClotureeGuard.class), sequences, mock(CaisseClotureeGuard.class),
                mock(CaisseCreditriceGuard.class),
                facturePartenaireRepository, enregistrerFactureUseCase,
                new RepartitionDetteMaintenanceService());
    }

    @Test
    @DisplayName("À payer : une dette par partenaire, et rien ne sort de la caisse")
    void a_credit_une_dette_par_partenaire() {
        Partenaire garage = partenaire(1L, "Garage Koné");
        Partenaire piecier = partenaire(2L, "Pièces Auto CI");
        donneeMaintenance(garage, List.of(
                element("Main d'œuvre", 30_000, null),
                element("Plaquettes", 20_000, piecier)),
                new BigDecimal("50000"));

        useCase.execute(1L, new BigDecimal("50000"), LE_10_MARS,
                ReglementMaintenance.aCredit(FIN_MARS), null, null);

        ArgumentCaptor<FacturePartenaire> dettes = ArgumentCaptor.forClass(FacturePartenaire.class);
        verify(enregistrerFactureUseCase, org.mockito.Mockito.times(2)).executer(dettes.capture());

        assertThat(dettes.getAllValues())
                .extracting(f -> f.getPartenaire().getId(), FacturePartenaire::getMontant)
                .containsExactly(
                        org.assertj.core.groups.Tuple.tuple(1L, new BigDecimal("30000")),
                        org.assertj.core.groups.Tuple.tuple(2L, new BigDecimal("20000")));
        assertThat(dettes.getAllValues()).allSatisfy(f -> {
            assertThat(f.getMaintenanceId()).isEqualTo(1L);
            assertThat(f.getDateFacture()).isEqualTo(LE_10_MARS);
            assertThat(f.getDateEcheance()).isEqualTo(FIN_MARS);
        });
        verify(operationRepository, never()).save(any());
    }

    @Test
    @DisplayName("Une ligne sans fournisseur revient au partenaire de l'intervention")
    void ligne_sans_partenaire_revient_a_l_intervention() {
        donneeMaintenance(partenaire(1L, "Garage Koné"),
                List.of(element("Vidange", 25_000, null)), new BigDecimal("25000"));

        useCase.execute(1L, new BigDecimal("25000"), LE_10_MARS,
                ReglementMaintenance.aCredit(null), null, null);

        ArgumentCaptor<FacturePartenaire> dette = ArgumentCaptor.forClass(FacturePartenaire.class);
        verify(enregistrerFactureUseCase).executer(dette.capture());
        assertThat(dette.getValue().getPartenaire().getId()).isEqualTo(1L);
        assertThat(dette.getValue().getMontant()).isEqualByComparingTo("25000");
    }

    @Test
    @DisplayName("L'écart entre le coût validé et les lignes va au partenaire principal")
    void ecart_de_cout_porte_par_le_partenaire_principal() {
        Partenaire garage = partenaire(1L, "Garage Koné");
        Partenaire piecier = partenaire(2L, "Pièces Auto CI");
        donneeMaintenance(garage, List.of(
                element("Main d'œuvre", 30_000, garage),
                element("Plaquettes", 20_000, piecier)),
                new BigDecimal("55000"));

        useCase.execute(1L, new BigDecimal("55000"), LE_10_MARS,
                ReglementMaintenance.aCredit(FIN_MARS), null, null);

        ArgumentCaptor<FacturePartenaire> dettes = ArgumentCaptor.forClass(FacturePartenaire.class);
        verify(enregistrerFactureUseCase, org.mockito.Mockito.times(2)).executer(dettes.capture());
        assertThat(dettes.getAllValues())
                .extracting(f -> f.getPartenaire().getId(), FacturePartenaire::getMontant)
                .containsExactly(
                        org.assertj.core.groups.Tuple.tuple(1L, new BigDecimal("35000")),
                        org.assertj.core.groups.Tuple.tuple(2L, new BigDecimal("20000")));
    }

    @Test
    @DisplayName("Sans aucun partenaire, la dette est refusée plutôt que créée dans le vide")
    void sans_partenaire_la_dette_est_refusee() {
        donneeMaintenance(null, List.of(element("Vidange", 25_000, null)), new BigDecimal("25000"));

        assertThatThrownBy(() -> useCase.execute(1L, new BigDecimal("25000"), LE_10_MARS,
                ReglementMaintenance.aCredit(null), null, null))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("partenaire");

        verify(enregistrerFactureUseCase, never()).executer(any());
    }

    @Test
    @DisplayName("Une intervention déjà endettée n'est pas facturée deux fois")
    void pas_de_double_dette() {
        donneeMaintenance(partenaire(1L, "Garage Koné"),
                List.of(element("Vidange", 25_000, null)), new BigDecimal("25000"));
        when(facturePartenaireRepository.findByMaintenanceId(1L)).thenReturn(List.of(
                FacturePartenaire.builder().id(9L).statut(StatutFacturePartenaire.A_PAYER).build()));

        assertThatThrownBy(() -> useCase.execute(1L, new BigDecimal("25000"), LE_10_MARS,
                ReglementMaintenance.aCredit(null), null, null))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("déjà une dette");

        verify(enregistrerFactureUseCase, never()).executer(any());
    }

    @Test
    @DisplayName("Comptant : la dépense est payée, aucune dette n'apparaît")
    void comptant_ne_cree_aucune_dette() {
        donneeMaintenance(partenaire(1L, "Garage Koné"),
                List.of(element("Vidange", 25_000, null)), new BigDecimal("25000"));

        useCase.execute(1L, new BigDecimal("25000"), LE_10_MARS,
                ReglementMaintenance.comptant(ModePaiement.ESPECES), null, null);

        verify(enregistrerFactureUseCase, never()).executer(any());
        ArgumentCaptor<OperationFinanciere> depense = ArgumentCaptor.forClass(OperationFinanciere.class);
        verify(operationRepository).save(depense.capture());
        assertThat(depense.getValue().getMontant()).isEqualByComparingTo("25000");
    }

    // ── Fixtures ─────────────────────────────────────────────────────────

    private void donneeMaintenance(Partenaire partenaire, List<ElementMaintenance> elements,
                                   BigDecimal cout) {
        Maintenance maintenance = Maintenance.builder()
                .id(1L)
                .type("VIDANGE")
                .datePrevue(LE_10_MARS)
                .cout(cout)
                .partenaire(partenaire)
                .vehicule(Vehicule.builder().id(3L).immatriculation("AA-123-BB").build())
                .detailMaintenance(DetailMaintenance.builder().elements(elements).build())
                .build();
        when(maintenanceRepository.findById(1L)).thenReturn(Optional.of(maintenance));
    }

    private static Partenaire partenaire(Long id, String nom) {
        return Partenaire.builder().id(id).nom(nom).build();
    }

    private static ElementMaintenance element(String libelle, int montant, Partenaire partenaire) {
        return ElementMaintenance.builder()
                .libelle(libelle)
                .montant(new BigDecimal(montant))
                .partenaire(partenaire)
                .build();
    }
}
