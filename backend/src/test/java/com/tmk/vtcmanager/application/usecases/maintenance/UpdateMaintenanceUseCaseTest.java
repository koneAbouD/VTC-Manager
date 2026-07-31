package com.tmk.vtcmanager.application.usecases.maintenance;

import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import com.tmk.vtcmanager.application.domain.operation.DetailMaintenance;
import com.tmk.vtcmanager.application.domain.operation.ElementMaintenance;
import com.tmk.vtcmanager.application.ports.event.VehiculeStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import com.tmk.vtcmanager.application.ports.persistence.MaintenanceRepository;
import com.tmk.vtcmanager.application.services.PeriodeClotureeGuard;
import com.tmk.vtcmanager.application.services.SynchronisationDetteMaintenanceService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Le formulaire de maintenance ne saisit pas le coût — il est fixé à la
 * clôture. Une requête qui n'en parle pas ne doit donc rien effacer.
 */
class UpdateMaintenanceUseCaseTest {

    private static final LocalDate LE_10_MARS = LocalDate.of(2026, 3, 10);

    private MaintenanceRepository maintenanceRepository;
    private SynchronisationDetteMaintenanceService synchronisation;
    private UpdateMaintenanceUseCase useCase;

    @BeforeEach
    void setUp() {
        maintenanceRepository = mock(MaintenanceRepository.class);
        synchronisation = mock(SynchronisationDetteMaintenanceService.class);
        when(maintenanceRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        useCase = new UpdateMaintenanceUseCase(maintenanceRepository,
                mock(CategorieOperationRepository.class),
                mock(VehiculeStatutEventPublisher.class),
                mock(PeriodeClotureeGuard.class),
                synchronisation);
    }

    @Test
    @DisplayName("Requête sans coût : celui de l'intervention est conservé")
    void cout_absent_est_conserve() {
        existante(new BigDecimal("55000"));

        useCase.execute(1L, Maintenance.builder()
                .datePrevue(LE_10_MARS)
                .detailMaintenance(DetailMaintenance.builder()
                        .elements(List.of(element("Revision", "25000"))).build())
                .build());

        assertThat(capturee().getCout()).isEqualByComparingTo("55000");
    }

    @Test
    @DisplayName("Coût fourni : il remplace l'ancien")
    void cout_fourni_remplace() {
        existante(new BigDecimal("55000"));

        useCase.execute(1L, Maintenance.builder()
                .datePrevue(LE_10_MARS)
                .cout(new BigDecimal("30000"))
                .build());

        assertThat(capturee().getCout()).isEqualByComparingTo("30000");
    }

    @Test
    @DisplayName("Les lignes modifiées sont enregistrées, puis les dettes réalignées")
    void lignes_enregistrees_et_dettes_synchronisees() {
        existante(new BigDecimal("55000"));

        useCase.execute(1L, Maintenance.builder()
                .datePrevue(LE_10_MARS)
                .detailMaintenance(DetailMaintenance.builder()
                        .elements(List.of(element("Revision", "25000"))).build())
                .build());

        assertThat(capturee().getDetailMaintenance().getElements())
                .extracting(ElementMaintenance::getEffectiveLibelle)
                .containsExactly("Revision");
        verify(synchronisation).synchroniser(any());
    }

    // ── Fixtures ─────────────────────────────────────────────────────────

    private void existante(BigDecimal cout) {
        when(maintenanceRepository.findById(1L)).thenReturn(Optional.of(Maintenance.builder()
                .id(1L)
                .type("VIDANGE")
                .statut(MaintenanceStatus.TERMINEE)
                .dateEffectuee(LE_10_MARS)
                .cout(cout)
                .detailMaintenance(DetailMaintenance.builder()
                        .id(7L)
                        .elements(List.of(element("Main d'œuvre", "55000")))
                        .build())
                .build()));
    }

    private Maintenance capturee() {
        ArgumentCaptor<Maintenance> captor = ArgumentCaptor.forClass(Maintenance.class);
        verify(maintenanceRepository).save(captor.capture());
        return captor.getValue();
    }

    private static ElementMaintenance element(String libelle, String montant) {
        return ElementMaintenance.builder()
                .libelle(libelle)
                .montant(new BigDecimal(montant))
                .build();
    }
}
