package com.tmk.vtcmanager.application.usecases.operationFinanciere;

import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.application.exception.PeriodeClotureeException;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.ports.security.AuteurCourant;
import com.tmk.vtcmanager.application.services.AnnulationEncaissementService;
import com.tmk.vtcmanager.application.services.AnnulationMaintenanceService;
import com.tmk.vtcmanager.application.services.CaisseClotureeGuard;
import com.tmk.vtcmanager.application.services.PeriodeClotureeGuard;
import com.tmk.vtcmanager.application.services.SequenceReferenceService;
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
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Correction d'une écriture par contre-passation.
 *
 * <p>Une erreur se découvre souvent après la clôture du mois où elle a été
 * commise. La corriger ne consiste pas à retoucher ce mois — il est publié —
 * mais à passer une écriture inverse dans le mois courant. C'est donc
 * l'extourne, et elle seule, qui doit tomber dans une période ouverte.
 */
class AnnulerOperationFinanciereUseCaseTest {

    private static final LocalDate MOIS_CLOS = LocalDate.of(2026, 7, 12);

    private OperationFinanciereRepository operationRepository;
    private PeriodeClotureeGuard periodeClotureeGuard;
    private AnnulerOperationFinanciereUseCase useCase;

    @BeforeEach
    void setUp() {
        operationRepository = mock(OperationFinanciereRepository.class);
        periodeClotureeGuard = mock(PeriodeClotureeGuard.class);
        AnnulationEncaissementService annulationEncaissement =
                mock(AnnulationEncaissementService.class);
        AnnulationMaintenanceService annulationMaintenance =
                mock(AnnulationMaintenanceService.class);
        SequenceReferenceService sequences = mock(SequenceReferenceService.class);
        AuteurCourant auteurCourant = mock(AuteurCourant.class);
        CaisseClotureeGuard caisseClotureeGuard = mock(CaisseClotureeGuard.class);

        when(sequences.suivante(any(), any())).thenReturn("EXT-2026-000001");
        when(auteurCourant.nom()).thenReturn("gerant");
        when(operationRepository.save(any())).thenAnswer(i -> i.getArgument(0));

        useCase = new AnnulerOperationFinanciereUseCase(operationRepository,
                annulationEncaissement, annulationMaintenance, periodeClotureeGuard,
                sequences, auteurCourant, caisseClotureeGuard);
    }

    private void ecritureExistante(LocalDate date) {
        when(operationRepository.findById(1L)).thenReturn(Optional.of(OperationFinanciere.builder()
                .id(1L)
                .reference("DEP-2026-000042")
                .typeOperation(TypeOperation.DEPENSE)
                .montant(BigDecimal.valueOf(75_000))
                .dateOperation(date)
                .build()));
    }

    private List<OperationFinanciere> ecrituresSauvees() {
        ArgumentCaptor<OperationFinanciere> captor =
                ArgumentCaptor.forClass(OperationFinanciere.class);
        verify(operationRepository, times(2)).save(captor.capture());
        return captor.getAllValues();
    }

    @Test
    @DisplayName("Une écriture d'un mois clos reste corrigeable par contre-passation")
    void ecriture_close_extournable() {
        ecritureExistante(MOIS_CLOS);

        useCase.execute(1L, "montant erroné");

        // L'origine garde sa date : le mois publié ne bouge pas.
        List<OperationFinanciere> sauvees = ecrituresSauvees();
        assertThat(sauvees.get(0).getDateOperation()).isEqualTo(MOIS_CLOS);
        assertThat(sauvees.get(0).getMotifAnnulation()).isEqualTo("montant erroné");
        // L'extourne porte le montant opposé et la date du jour.
        assertThat(sauvees.get(1).getExtourneDeId()).isEqualTo(1L);
        assertThat(sauvees.get(1).getMontant()).isEqualByComparingTo("-75000");
        assertThat(sauvees.get(1).getDateOperation()).isEqualTo(LocalDate.now());
    }

    @Test
    @DisplayName("La correction est refusée si le mois courant est lui aussi clos")
    void extourne_dans_periode_close_refusee() {
        ecritureExistante(MOIS_CLOS);
        doThrow(new PeriodeClotureeException(LocalDate.now()))
                .when(periodeClotureeGuard).verifier(LocalDate.now());

        assertThatThrownBy(() -> useCase.execute(1L, "montant erroné"))
                .isInstanceOf(PeriodeClotureeException.class);
    }

    @Test
    @DisplayName("Le motif est obligatoire : il justifie la contre-passation")
    void motif_obligatoire() {
        assertThatThrownBy(() -> useCase.execute(1L, "  "))
                .isInstanceOf(IllegalArgumentException.class);
    }
}
