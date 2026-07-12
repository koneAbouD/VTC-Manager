package com.tmk.vtcmanager.application.usecases.arrete;

import com.tmk.vtcmanager.application.domain.arrete.ArreteCompte;
import com.tmk.vtcmanager.application.domain.arrete.LigneArrete;
import com.tmk.vtcmanager.application.domain.arrete.PerimetreArrete;
import com.tmk.vtcmanager.application.domain.arrete.ReglementArrete;
import com.tmk.vtcmanager.application.domain.arrete.SensArrete;
import com.tmk.vtcmanager.application.domain.arrete.StatutArrete;
import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.recette.Encaissement;
import com.tmk.vtcmanager.application.ports.persistence.ArreteCompteRepository;
import com.tmk.vtcmanager.application.ports.persistence.ContraventionRepository;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementPenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.services.PeriodeClotureeGuard;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class AnnulerArreteUseCaseTest {

    private ArreteCompteRepository arreteCompteRepository;
    private LigneCotisationRepository ligneCotisationRepository;
    private LigneRecetteRepository ligneRecetteRepository;
    private EncaissementRepository encaissementRepository;
    private LignePenaliteRepository lignePenaliteRepository;
    private EncaissementPenaliteRepository encaissementPenaliteRepository;
    private ContraventionRepository contraventionRepository;
    private OperationFinanciereRepository operationFinanciereRepository;
    private PeriodeClotureeGuard periodeClotureeGuard;
    private AnnulerArreteUseCase useCase;

    @BeforeEach
    void setUp() {
        arreteCompteRepository = mock(ArreteCompteRepository.class);
        ligneCotisationRepository = mock(LigneCotisationRepository.class);
        ligneRecetteRepository = mock(LigneRecetteRepository.class);
        encaissementRepository = mock(EncaissementRepository.class);
        lignePenaliteRepository = mock(LignePenaliteRepository.class);
        encaissementPenaliteRepository = mock(EncaissementPenaliteRepository.class);
        contraventionRepository = mock(ContraventionRepository.class);
        operationFinanciereRepository = mock(OperationFinanciereRepository.class);
        periodeClotureeGuard = mock(PeriodeClotureeGuard.class);
        useCase = new AnnulerArreteUseCase(arreteCompteRepository, ligneCotisationRepository,
                ligneRecetteRepository, encaissementRepository, lignePenaliteRepository,
                encaissementPenaliteRepository, contraventionRepository, operationFinanciereRepository,
                periodeClotureeGuard);
    }

    private ArreteCompte arreteValide() {
        return ArreteCompte.builder()
                .id(1L).perimetre(PerimetreArrete.CHAUFFEUR).perimetreId(7L)
                .periodeDebut(LocalDate.of(2026, 6, 1)).periodeFin(LocalDate.of(2026, 6, 30))
                .dateArrete(LocalDate.of(2026, 7, 1)).reference("ARR-2026-x").statut(StatutArrete.VALIDE)
                .reglements(List.of(ReglementArrete.builder()
                        .chauffeurId(7L).montantNet(BigDecimal.valueOf(70))
                        .operationDecaissementId(500L).build()))
                .lignes(List.of(
                        LigneArrete.builder().document(TypeDocumentCreance.COTISATION).documentId(100L)
                                .montant(BigDecimal.valueOf(100)).sens(SensArrete.CREDIT).build(),
                        LigneArrete.builder().document(TypeDocumentCreance.RECETTE).documentId(200L)
                                .montant(BigDecimal.valueOf(30)).sens(SensArrete.DEBIT).operationId(300L).build()))
                .build();
    }

    @Test
    void annule_contre_passe_decaissement_compensation_et_restitution() {
        when(arreteCompteRepository.findById(1L)).thenReturn(Optional.of(arreteValide()));
        when(operationFinanciereRepository.findById(anyLong())).thenAnswer(inv ->
                Optional.of(OperationFinanciere.builder().id(inv.getArgument(0)).statut(StatutOperation.ENCAISSE).build()));
        when(encaissementRepository.findByOperationFinanciereId(300L))
                .thenReturn(Optional.of(Encaissement.builder().id(700L).build()));

        useCase.executer(1L, "Erreur de saisie");

        // Décaissement (500) + compensation recette (300) passés en ANNULEE.
        ArgumentCaptor<OperationFinanciere> ops = ArgumentCaptor.forClass(OperationFinanciere.class);
        verify(operationFinanciereRepository, org.mockito.Mockito.times(2)).save(ops.capture());
        assertThat(ops.getAllValues()).allMatch(o -> o.getStatut() == StatutOperation.ANNULEE);

        verify(encaissementRepository).deleteById(700L);
        verify(ligneRecetteRepository).recalculerDepuisEncaissements(200L);
        verify(ligneCotisationRepository).annulerRestitution(100L);
        verify(arreteCompteRepository).annuler(1L, "Erreur de saisie");
    }

    @Test
    void refuse_motif_vide() {
        assertThatThrownBy(() -> useCase.executer(1L, "  "))
                .isInstanceOf(IllegalArgumentException.class);
        verify(arreteCompteRepository, never()).annuler(anyLong(), org.mockito.ArgumentMatchers.anyString());
    }

    @Test
    void refuse_arrete_deja_annule() {
        ArreteCompte annule = arreteValide();
        annule.setStatut(StatutArrete.ANNULE);
        when(arreteCompteRepository.findById(1L)).thenReturn(Optional.of(annule));

        assertThatThrownBy(() -> useCase.executer(1L, "motif"))
                .isInstanceOf(IllegalStateException.class);
        verify(arreteCompteRepository, never()).annuler(anyLong(), org.mockito.ArgumentMatchers.anyString());
    }
}
