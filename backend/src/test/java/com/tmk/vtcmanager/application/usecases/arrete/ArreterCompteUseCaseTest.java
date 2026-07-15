package com.tmk.vtcmanager.application.usecases.arrete;

import com.tmk.vtcmanager.application.domain.arrete.ArreteCompte;
import com.tmk.vtcmanager.application.domain.arrete.PerimetreArrete;
import com.tmk.vtcmanager.application.domain.arrete.ReglementArrete;
import com.tmk.vtcmanager.application.domain.arrete.StatutArrete;
import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;
import com.tmk.vtcmanager.application.domain.finance.LigneCreance;
import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.application.ports.persistence.ArreteCompteRepository;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.application.ports.persistence.ContraventionRepository;
import com.tmk.vtcmanager.application.ports.persistence.CreanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementPenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.services.CompteTresorerieResolver;
import com.tmk.vtcmanager.application.services.PeriodeClotureeGuard;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Invariant d'arrêté de compte : le fonds de cotisation compense les créances
 * par des opérations <b>cash-neutres</b> (compte de trésorerie null) et seul le
 * net positif est décaissé sur un compte réel.
 */
class ArreterCompteUseCaseTest {

    private LigneCotisationRepository ligneCotisationRepository;
    private LigneRecetteRepository ligneRecetteRepository;
    private EncaissementRepository encaissementRepository;
    private LignePenaliteRepository lignePenaliteRepository;
    private EncaissementPenaliteRepository encaissementPenaliteRepository;
    private ContraventionRepository contraventionRepository;
    private OperationFinanciereRepository operationFinanciereRepository;
    private CategorieOperationRepository categorieOperationRepository;
    private CreanceRepository creanceRepository;
    private ChauffeurRepository chauffeurRepository;
    private ArreteCompteRepository arreteCompteRepository;
    private CompteTresorerieResolver compteTresorerieResolver;
    private PeriodeClotureeGuard periodeClotureeGuard;

    private ArreterCompteUseCase useCase;

    private static final Long CHAUFFEUR = 1L;
    private static final Long VEHICULE = 10L;
    private static final LocalDate DEBUT = LocalDate.of(2026, 6, 1);
    private static final LocalDate FIN = LocalDate.of(2026, 6, 30);

    @BeforeEach
    void setUp() {
        ligneCotisationRepository = mock(LigneCotisationRepository.class);
        ligneRecetteRepository = mock(LigneRecetteRepository.class);
        encaissementRepository = mock(EncaissementRepository.class);
        lignePenaliteRepository = mock(LignePenaliteRepository.class);
        encaissementPenaliteRepository = mock(EncaissementPenaliteRepository.class);
        contraventionRepository = mock(ContraventionRepository.class);
        operationFinanciereRepository = mock(OperationFinanciereRepository.class);
        categorieOperationRepository = mock(CategorieOperationRepository.class);
        creanceRepository = mock(CreanceRepository.class);
        chauffeurRepository = mock(ChauffeurRepository.class);
        arreteCompteRepository = mock(ArreteCompteRepository.class);
        compteTresorerieResolver = mock(CompteTresorerieResolver.class);
        periodeClotureeGuard = mock(PeriodeClotureeGuard.class);

        CalculerCompteCourantUseCase calculer = new CalculerCompteCourantUseCase(
                ligneCotisationRepository, creanceRepository, chauffeurRepository);
        useCase = new ArreterCompteUseCase(calculer, arreteCompteRepository, ligneCotisationRepository,
                ligneRecetteRepository, encaissementRepository, lignePenaliteRepository,
                encaissementPenaliteRepository, contraventionRepository, operationFinanciereRepository,
                categorieOperationRepository, compteTresorerieResolver, periodeClotureeGuard);

        // Catégorie renvoyée avec le code demandé (pour assertions).
        when(categorieOperationRepository.findByCode(anyString()))
                .thenAnswer(inv -> Optional.of(CategorieOperation.builder().code(inv.getArgument(0)).build()));
        // Opérations : id auto-attribué à la sauvegarde.
        when(operationFinanciereRepository.save(any(OperationFinanciere.class)))
                .thenAnswer(inv -> {
                    OperationFinanciere op = inv.getArgument(0);
                    if (op.getId() == null) op.setId(999L);
                    return op;
                });
        when(encaissementRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(chauffeurRepository.findById(CHAUFFEUR)).thenReturn(Optional.of(
                Chauffeur.builder().id(CHAUFFEUR).nom("Kone").prenom("Ali").build()));
        when(arreteCompteRepository.enregistrerEntete(any(ArreteCompte.class)))
                .thenAnswer(inv -> { ArreteCompte a = inv.getArgument(0); a.setId(1L); return a; });
        when(arreteCompteRepository.findById(1L)).thenReturn(Optional.of(
                ArreteCompte.builder().id(1L).perimetre(PerimetreArrete.CHAUFFEUR)
                        .statut(StatutArrete.VALIDE).build()));
    }

    private LigneCotisation cotisation(BigDecimal encaisse) {
        return cotisation(100L, encaisse);
    }

    private LigneCotisation cotisation(Long id, BigDecimal encaisse) {
        return LigneCotisation.builder()
                .id(id).vehiculeId(VEHICULE).chauffeurId(CHAUFFEUR)
                .dateCotisation(LocalDate.of(2026, 6, 15)).nomCotisation("Entretien")
                .montantDu(encaisse).montantEncaisse(encaisse)
                .statut(StatutLigneCotisation.ENCAISSE).build();
    }

    private LigneCreance recette(Long id, BigDecimal restant) {
        return LigneCreance.builder()
                .document(TypeDocumentCreance.RECETTE).documentId(id)
                .vehiculeId(VEHICULE).chauffeurId(CHAUFFEUR)
                .dateReference(LocalDate.of(2026, 6, 10))
                .montantDu(restant).montantRegle(BigDecimal.ZERO).restant(restant).build();
    }

    @Test
    void net_positif_compense_cash_neutre_et_decaisse_le_net() {
        // Fonds 100, une recette due 30 → net 70.
        when(ligneCotisationRepository.findByCriteres(any()))
                .thenReturn(List.of(cotisation(BigDecimal.valueOf(100))));
        when(creanceRepository.getLignesCreance(CHAUFFEUR))
                .thenReturn(List.of(recette(200L, BigDecimal.valueOf(30))));
        when(compteTresorerieResolver.resoudre(any(), eq(ModePaiement.ESPECES))).thenReturn(5L);

        useCase.executer(PerimetreArrete.CHAUFFEUR, CHAUFFEUR, DEBUT, FIN,
                LocalDate.of(2026, 7, 1), ModePaiement.ESPECES, null);

        ArgumentCaptor<OperationFinanciere> ops = ArgumentCaptor.forClass(OperationFinanciere.class);
        verify(operationFinanciereRepository, org.mockito.Mockito.times(2)).save(ops.capture());

        OperationFinanciere compensation = ops.getAllValues().stream()
                .filter(o -> "ENCAISSEMENT_RECETTES".equals(o.getCategorie().getCode())).findFirst().orElseThrow();
        assertThat(compensation.getCompteTresorerieId()).isNull(); // cash-neutre
        assertThat(compensation.getMontant()).isEqualByComparingTo("30");
        assertThat(compensation.getTypeOperation()).isEqualTo(TypeOperation.REVENU);

        OperationFinanciere decaissement = ops.getAllValues().stream()
                .filter(o -> "RESTITUTION_COTISATIONS".equals(o.getCategorie().getCode())).findFirst().orElseThrow();
        assertThat(decaissement.getCompteTresorerieId()).isEqualTo(5L); // compte réel
        assertThat(decaissement.getMontant()).isEqualByComparingTo("70");
        assertThat(decaissement.getTypeOperation()).isEqualTo(TypeOperation.DEPENSE);

        verify(ligneRecetteRepository).recalculerDepuisEncaissements(200L);
        verify(ligneCotisationRepository).marquerRestituee(100L, 1L);

        ArgumentCaptor<List<ReglementArrete>> reglements = ArgumentCaptor.forClass(List.class);
        verify(arreteCompteRepository).enregistrerReglements(reglements.capture());
        ReglementArrete r = reglements.getValue().get(0);
        assertThat(r.getMontantNet()).isEqualByComparingTo("70");
        assertThat(r.getTotalCreancesCompensees()).isEqualByComparingTo("30");
        assertThat(r.getReliquatReporte()).isEqualByComparingTo("0");
    }

    @Test
    void selection_partielle_ne_restitue_que_les_lignes_choisies() {
        // Deux cotisations (100, 40) et deux recettes (30, 50). Sélection : cotisation 100
        // seule + recette 201 seule → fonds 100, compensé 50, net 50. Le reste intact.
        when(ligneCotisationRepository.findByCriteres(any())).thenReturn(List.of(
                cotisation(100L, BigDecimal.valueOf(100)),
                cotisation(101L, BigDecimal.valueOf(40))));
        when(creanceRepository.getLignesCreance(CHAUFFEUR)).thenReturn(List.of(
                recette(200L, BigDecimal.valueOf(30)),
                recette(201L, BigDecimal.valueOf(50))));
        when(compteTresorerieResolver.resoudre(any(), eq(ModePaiement.ESPECES))).thenReturn(5L);

        SelectionArrete selection = new SelectionArrete(
                java.util.Set.of(100L),
                java.util.Set.of(new SelectionArrete.CreanceKey(TypeDocumentCreance.RECETTE, 201L)));

        useCase.executer(PerimetreArrete.CHAUFFEUR, CHAUFFEUR, DEBUT, FIN,
                LocalDate.of(2026, 7, 1), ModePaiement.ESPECES, null, selection);

        ArgumentCaptor<OperationFinanciere> ops = ArgumentCaptor.forClass(OperationFinanciere.class);
        verify(operationFinanciereRepository, org.mockito.Mockito.times(2)).save(ops.capture());

        OperationFinanciere compensation = ops.getAllValues().stream()
                .filter(o -> "ENCAISSEMENT_RECETTES".equals(o.getCategorie().getCode())).findFirst().orElseThrow();
        assertThat(compensation.getMontant()).isEqualByComparingTo("50"); // recette 201 uniquement
        assertThat(compensation.getCompteTresorerieId()).isNull();

        OperationFinanciere decaissement = ops.getAllValues().stream()
                .filter(o -> "RESTITUTION_COTISATIONS".equals(o.getCategorie().getCode())).findFirst().orElseThrow();
        assertThat(decaissement.getMontant()).isEqualByComparingTo("50"); // net = 100 − 50

        // Seules les lignes sélectionnées bougent.
        verify(ligneRecetteRepository).recalculerDepuisEncaissements(201L);
        verify(ligneRecetteRepository, never()).recalculerDepuisEncaissements(200L);
        verify(ligneCotisationRepository).marquerRestituee(100L, 1L);
        verify(ligneCotisationRepository, never()).marquerRestituee(eq(101L), anyLong());
    }

    @Test
    void solde_debiteur_reporte_le_reliquat_sans_decaisser() {
        // Fonds 100, créances 80 + 50 = 130 → net 0, reliquat 30.
        when(ligneCotisationRepository.findByCriteres(any()))
                .thenReturn(List.of(cotisation(BigDecimal.valueOf(100))));
        when(creanceRepository.getLignesCreance(CHAUFFEUR)).thenReturn(List.of(
                recette(200L, BigDecimal.valueOf(80)),
                recette(201L, BigDecimal.valueOf(50))));

        useCase.executer(PerimetreArrete.CHAUFFEUR, CHAUFFEUR, DEBUT, FIN,
                LocalDate.of(2026, 7, 1), ModePaiement.ESPECES, null);

        ArgumentCaptor<OperationFinanciere> ops = ArgumentCaptor.forClass(OperationFinanciere.class);
        verify(operationFinanciereRepository, org.mockito.Mockito.times(2)).save(ops.capture());
        // Aucune restitution : les 2 opérations sont des compensations cash-neutres.
        assertThat(ops.getAllValues())
                .allMatch(o -> "ENCAISSEMENT_RECETTES".equals(o.getCategorie().getCode()))
                .allMatch(o -> o.getCompteTresorerieId() == null);
        // Première créance compensée 80, seconde partielle 20 (fonds épuisé).
        assertThat(ops.getAllValues()).extracting(OperationFinanciere::getMontant)
                .usingElementComparator(BigDecimal::compareTo)
                .containsExactlyInAnyOrder(BigDecimal.valueOf(80), BigDecimal.valueOf(20));

        verify(compteTresorerieResolver, never()).resoudre(any(), any());

        ArgumentCaptor<List<ReglementArrete>> reglements = ArgumentCaptor.forClass(List.class);
        verify(arreteCompteRepository).enregistrerReglements(reglements.capture());
        ReglementArrete r = reglements.getValue().get(0);
        assertThat(r.getMontantNet()).isEqualByComparingTo("0");
        assertThat(r.getReliquatReporte()).isEqualByComparingTo("30");
        verify(ligneCotisationRepository).marquerRestituee(100L, 1L);
    }
}
