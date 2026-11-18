package com.tmk.vtcmanager.application.usecases.vehicule;

import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.domain.vehicule.Vidange;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.exception.VehiculeNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import com.tmk.vtcmanager.application.ports.persistence.VidangeRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Correction de la dernière vidange saisie : seule la plus récente se modifie,
 * elle garde son identité (UPDATE, pas de doublon) et ne peut pas reculer
 * derrière la vidange précédente.
 */
class ModifierDerniereVidangeUseCaseTest {

    private static final Long VEHICULE = 5L;
    private static final LocalDate JOUR = LocalDate.of(2026, 4, 10);

    private VidangeRepository vidangeRepository;
    private VehiculeRepository vehiculeRepository;
    private ModifierDerniereVidangeUseCase useCase;

    private Vidange derniere;
    private Vidange precedente;

    @BeforeEach
    void setUp() {
        vidangeRepository = mock(VidangeRepository.class);
        vehiculeRepository = mock(VehiculeRepository.class);
        when(vehiculeRepository.findById(VEHICULE))
                .thenReturn(Optional.of(Vehicule.builder().id(VEHICULE).build()));
        when(vidangeRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        derniere = Vidange.builder().id(20L).vehiculeId(VEHICULE).maintenanceId(7L)
                .dateVidange(JOUR).kilometrageVidange(120_000)
                .dateProchaineVidange(JOUR.plusMonths(3)).kilometrageProchaineVidange(125_000)
                .build();
        precedente = Vidange.builder().id(10L).vehiculeId(VEHICULE)
                .dateVidange(JOUR.minusMonths(3)).kilometrageVidange(115_000)
                .build();
        when(vidangeRepository.findByVehiculeId(VEHICULE)).thenReturn(List.of(derniere, precedente));

        useCase = new ModifierDerniereVidangeUseCase(vidangeRepository, vehiculeRepository);
    }

    private Vidange correction(LocalDate date, Integer km, LocalDate dateCible, Integer kmCible) {
        return Vidange.builder()
                .dateVidange(date).kilometrageVidange(km)
                .dateProchaineVidange(dateCible).kilometrageProchaineVidange(kmCible)
                .build();
    }

    @Test
    @DisplayName("La dernière vidange est corrigée en gardant son id, son véhicule et sa maintenance")
    void correction_nominale() {
        Vidange saved = useCase.execute(VEHICULE, 20L,
                correction(JOUR.plusDays(1), 121_000, JOUR.plusMonths(4), 126_000));

        assertThat(saved.getId()).isEqualTo(20L);
        assertThat(saved.getVehiculeId()).isEqualTo(VEHICULE);
        assertThat(saved.getMaintenanceId()).isEqualTo(7L);
        assertThat(saved.getKilometrageVidange()).isEqualTo(121_000);
        assertThat(saved.getKilometrageProchaineVidange()).isEqualTo(126_000);
    }

    @Test
    @DisplayName("Vider la cible retire la prochaine vidange")
    void cible_videe() {
        Vidange saved = useCase.execute(VEHICULE, 20L, correction(JOUR, 120_000, null, null));

        assertThat(saved.getDateProchaineVidange()).isNull();
        assertThat(saved.getKilometrageProchaineVidange()).isNull();
    }

    @Test
    @DisplayName("Une vidange plus ancienne n'est pas modifiable")
    void ancienne_refusee() {
        assertThatThrownBy(() -> useCase.execute(VEHICULE, 10L, correction(JOUR, 120_000, null, null)))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("dernière");
        verify(vidangeRepository, never()).save(any());
    }

    @Test
    @DisplayName("Une vidange inconnue du véhicule est introuvable")
    void inconnue() {
        assertThatThrownBy(() -> useCase.execute(VEHICULE, 99L, correction(JOUR, 120_000, null, null)))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    @DisplayName("La correction ne peut pas passer avant la vidange précédente")
    void pas_avant_la_precedente() {
        assertThatThrownBy(() -> useCase.execute(VEHICULE, 20L,
                correction(JOUR.minusMonths(4), 120_000, null, null)))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("date");
        assertThatThrownBy(() -> useCase.execute(VEHICULE, 20L,
                correction(JOUR, 114_000, null, null)))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("kilométrage");
        verify(vidangeRepository, never()).save(any());
    }

    @Test
    @DisplayName("Les contrôles de cohérence de la cible s'appliquent")
    void cible_incoherente() {
        assertThatThrownBy(() -> useCase.execute(VEHICULE, 20L,
                correction(JOUR, 120_000, JOUR.minusDays(1), null)))
                .isInstanceOf(IllegalArgumentException.class);
        verify(vidangeRepository, never()).save(any());
    }

    @Test
    @DisplayName("Un véhicule inexistant est refusé")
    void vehicule_introuvable() {
        when(vehiculeRepository.findById(VEHICULE)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> useCase.execute(VEHICULE, 20L, correction(JOUR, 120_000, null, null)))
                .isInstanceOf(VehiculeNotFoundException.class);
    }
}
