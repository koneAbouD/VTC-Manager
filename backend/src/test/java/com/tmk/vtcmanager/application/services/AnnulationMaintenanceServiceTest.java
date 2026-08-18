package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.ports.event.VehiculeStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.MaintenanceRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

/**
 * Annuler la dépense issue d'une complétion de maintenance doit défaire la
 * complétion elle-même : la maintenance repasse en PLANIFIEE — l'intervention
 * est à refaire en entier — et le véhicule redevient indisponible. Sans cela,
 * l'atelier disparaîtrait des écrans alors que la voiture y est toujours.
 */
class AnnulationMaintenanceServiceTest {

    private static final Long MAINTENANCE_ID = 300L;

    private MaintenanceRepository maintenanceRepository;
    private VehiculeStatutEventPublisher statutEventPublisher;
    private AnnulationMaintenanceService service;

    @BeforeEach
    void setUp() {
        maintenanceRepository = mock(MaintenanceRepository.class);
        statutEventPublisher = mock(VehiculeStatutEventPublisher.class);
        when(maintenanceRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        service = new AnnulationMaintenanceService(maintenanceRepository, statutEventPublisher);
    }

    private OperationFinanciere operationLiee() {
        return OperationFinanciere.builder().id(1L).maintenanceId(MAINTENANCE_ID).build();
    }

    private Maintenance maintenanceTerminee() {
        return Maintenance.builder()
                .id(MAINTENANCE_ID)
                .statut(MaintenanceStatus.TERMINEE)
                .dateEffectuee(LocalDate.of(2026, 4, 10))
                .cout(BigDecimal.valueOf(85_000))
                .vehicule(Vehicule.builder().id(7L).build())
                .build();
    }

    @Test
    @DisplayName("La maintenance repart PLANIFIEE, sans date ni coût")
    void maintenance_rouverte() {
        when(maintenanceRepository.findById(MAINTENANCE_ID)).thenReturn(Optional.of(maintenanceTerminee()));

        service.reouvrirMaintenanceLiee(operationLiee());

        ArgumentCaptor<Maintenance> capture = ArgumentCaptor.forClass(Maintenance.class);
        verify(maintenanceRepository).save(capture.capture());
        Maintenance rouverte = capture.getValue();

        assertThat(rouverte.getStatut()).isEqualTo(MaintenanceStatus.PLANIFIEE);
        assertThat(rouverte.getDateEffectuee()).isNull();
        assertThat(rouverte.getCout()).isNull();
    }

    @Test
    @DisplayName("Le statut du véhicule est recalculé : il retourne en maintenance")
    void statut_vehicule_recalcule() {
        when(maintenanceRepository.findById(MAINTENANCE_ID)).thenReturn(Optional.of(maintenanceTerminee()));

        service.reouvrirMaintenanceLiee(operationLiee());

        verify(statutEventPublisher).publishStatutDirty(7L);
    }

    @Test
    @DisplayName("Une maintenance sans véhicule ne déclenche aucun recalcul")
    void maintenance_sans_vehicule() {
        Maintenance maintenance = maintenanceTerminee();
        maintenance.setVehicule(null);
        when(maintenanceRepository.findById(MAINTENANCE_ID)).thenReturn(Optional.of(maintenance));

        service.reouvrirMaintenanceLiee(operationLiee());

        verify(maintenanceRepository).save(any());
        verifyNoInteractions(statutEventPublisher);
    }

    @Test
    @DisplayName("Une maintenance déjà rouverte n'est pas retouchée (idempotent)")
    void deja_rouverte() {
        Maintenance enCours = maintenanceTerminee();
        enCours.setStatut(MaintenanceStatus.EN_COURS);
        when(maintenanceRepository.findById(MAINTENANCE_ID)).thenReturn(Optional.of(enCours));

        service.reouvrirMaintenanceLiee(operationLiee());

        verify(maintenanceRepository, never()).save(any());
        verifyNoInteractions(statutEventPublisher);
        // Le coût déjà effacé par la première annulation n'est pas restauré.
        assertThat(enCours.getCout()).isEqualByComparingTo("85000");
    }

    @Test
    @DisplayName("Une maintenance introuvable est ignorée sans erreur")
    void maintenance_introuvable() {
        when(maintenanceRepository.findById(MAINTENANCE_ID)).thenReturn(Optional.empty());

        assertThatCode(() -> service.reouvrirMaintenanceLiee(operationLiee()))
                .doesNotThrowAnyException();
        verify(maintenanceRepository, never()).save(any());
    }

    @Test
    @DisplayName("Une opération sans maintenance liée ne fait rien")
    void operation_sans_maintenance() {
        service.reouvrirMaintenanceLiee(OperationFinanciere.builder().id(1L).build());
        service.reouvrirMaintenanceLiee(null);

        verify(maintenanceRepository, never()).findById(anyLong());
        verifyNoInteractions(statutEventPublisher);
    }
}
