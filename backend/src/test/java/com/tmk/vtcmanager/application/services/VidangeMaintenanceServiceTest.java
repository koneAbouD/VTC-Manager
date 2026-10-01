package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.domain.vehicule.Vidange;
import com.tmk.vtcmanager.application.ports.persistence.VidangeRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.time.LocalDate;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class VidangeMaintenanceServiceTest {

    private static final long VEHICULE_ID = 5L;
    private static final LocalDate FAITE_LE = LocalDate.of(2026, 10, 1);

    private VidangeRepository vidangeRepository;
    private VidangeMaintenanceService service;

    @BeforeEach
    void setUp() {
        vidangeRepository = mock(VidangeRepository.class);
        when(vidangeRepository.findByMaintenanceId(anyLong())).thenReturn(Optional.empty());
        when(vidangeRepository.findDerniereByVehiculeId(anyLong())).thenReturn(Optional.empty());
        service = new VidangeMaintenanceService(vidangeRepository);
    }

    private Maintenance vidangeTerminee(Integer kmAuMoment, Integer kmVehicule) {
        return Maintenance.builder()
                .id(40L)
                .type("VIDANGE")
                .statut(MaintenanceStatus.TERMINEE)
                .dateEffectuee(FAITE_LE)
                .kilometrageAuMoment(kmAuMoment)
                .vehicule(Vehicule.builder().id(VEHICULE_ID).kilometrage(kmVehicule).build())
                .build();
    }

    private Vidange enregistree() {
        ArgumentCaptor<Vidange> captor = ArgumentCaptor.forClass(Vidange.class);
        verify(vidangeRepository).save(captor.capture());
        return captor.getValue();
    }

    @Test
    @DisplayName("La clôture enregistre la vidange au rythme de la précédente")
    void enregistreLaVidangeAuRythmeDeLaPrecedente() {
        when(vidangeRepository.findDerniereByVehiculeId(VEHICULE_ID)).thenReturn(Optional.of(
                Vidange.builder()
                        .dateVidange(LocalDate.of(2026, 7, 1))
                        .kilometrageVidange(90_000)
                        .dateProchaineVidange(LocalDate.of(2026, 10, 1))   // 92 jours
                        .kilometrageProchaineVidange(95_000)              // 5 000 km
                        .build()));

        service.enregistrerVidangeFaite(vidangeTerminee(95_200, 96_000));

        Vidange v = enregistree();
        assertThat(v.getVehiculeId()).isEqualTo(VEHICULE_ID);
        assertThat(v.getMaintenanceId()).isEqualTo(40L);
        assertThat(v.getDateVidange()).isEqualTo(FAITE_LE);
        // Le relevé de l'intervention prime sur le compteur du véhicule.
        assertThat(v.getKilometrageVidange()).isEqualTo(95_200);
        assertThat(v.getDateProchaineVidange()).isEqualTo(FAITE_LE.plusDays(92));
        assertThat(v.getKilometrageProchaineVidange()).isEqualTo(100_200);
    }

    @Test
    @DisplayName("Sans relevé, le compteur du véhicule ; sans précédente, pas de cible")
    void compteurDuVehiculeEtPasDeCibleSansPrecedente() {
        service.enregistrerVidangeFaite(vidangeTerminee(null, 96_000));

        Vidange v = enregistree();
        assertThat(v.getKilometrageVidange()).isEqualTo(96_000);
        assertThat(v.getDateProchaineVidange()).isNull();
        assertThat(v.getKilometrageProchaineVidange()).isNull();
    }

    @Test
    @DisplayName("Rien pour une autre intervention, une vidange déjà enregistrée ou sans kilométrage")
    void rienHorsDesCasUtiles() {
        Maintenance freins = vidangeTerminee(95_000, 96_000);
        freins.setType("FREINS");
        service.enregistrerVidangeFaite(freins);

        service.enregistrerVidangeFaite(vidangeTerminee(null, null));

        when(vidangeRepository.findByMaintenanceId(40L))
                .thenReturn(Optional.of(Vidange.builder().id(9L).build()));
        service.enregistrerVidangeFaite(vidangeTerminee(95_000, 96_000));

        verify(vidangeRepository, never()).save(any());
    }

    @Test
    @DisplayName("Défaire la complétion retire la vidange produite")
    void retireLaVidangeProduite() {
        when(vidangeRepository.findByMaintenanceId(40L))
                .thenReturn(Optional.of(Vidange.builder().id(9L).build()));

        service.retirerVidangeFaite(vidangeTerminee(95_000, 96_000));

        verify(vidangeRepository).deleteById(9L);
    }
}
