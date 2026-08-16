package com.tmk.vtcmanager.application.usecases.vehicule;

import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.domain.vehicule.Vidange;
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
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Suivi des vidanges. Chaque enregistrement est une ligne d'historique ; la
 * plus récente fait office de « dernière vidange » et sa cible de « prochaine
 * vidange ». Les contrôles de cohérence évitent les cibles absurdes (prochaine
 * vidange avant la vidange elle-même) qui feraient croire à un entretien en
 * retard dès sa saisie.
 */
class VidangeUseCasesTest {

    private static final Long VEHICULE = 5L;
    private static final LocalDate JOUR = LocalDate.of(2026, 4, 10);

    private VidangeRepository vidangeRepository;
    private VehiculeRepository vehiculeRepository;
    private CreateVidangeUseCase createUseCase;
    private GetVidangesByVehiculeUseCase getUseCase;

    @BeforeEach
    void setUp() {
        vidangeRepository = mock(VidangeRepository.class);
        vehiculeRepository = mock(VehiculeRepository.class);
        when(vehiculeRepository.findById(VEHICULE))
                .thenReturn(Optional.of(Vehicule.builder().id(VEHICULE).build()));
        when(vidangeRepository.save(any())).thenAnswer(inv -> {
            Vidange v = inv.getArgument(0);
            v.setId(150L);
            return v;
        });

        createUseCase = new CreateVidangeUseCase(vidangeRepository, vehiculeRepository);
        getUseCase = new GetVidangesByVehiculeUseCase(vidangeRepository);
    }

    private Vidange vidange(LocalDate date, Integer km, LocalDate dateCible, Integer kmCible) {
        return Vidange.builder()
                .dateVidange(date).kilometrageVidange(km)
                .dateProchaineVidange(dateCible).kilometrageProchaineVidange(kmCible)
                .commentaire("Huile 10W40")
                .build();
    }

    @Test
    @DisplayName("Une vidange valide est rattachée à son véhicule et enregistrée")
    void creation_nominale() {
        Vidange saved = createUseCase.execute(VEHICULE,
                vidange(JOUR, 120_000, JOUR.plusMonths(3), 125_000));

        assertThat(saved.getId()).isEqualTo(150L);
        assertThat(saved.getVehiculeId()).isEqualTo(VEHICULE);
        assertThat(saved.getKilometrageProchaineVidange()).isEqualTo(125_000);
    }

    @Test
    @DisplayName("La cible de prochaine vidange est facultative")
    void cible_facultative() {
        assertThatCode(() -> createUseCase.execute(VEHICULE, vidange(JOUR, 120_000, null, null)))
                .doesNotThrowAnyException();
    }

    @Test
    @DisplayName("Une vidange sans date est refusée")
    void date_obligatoire() {
        assertThatThrownBy(() -> createUseCase.execute(VEHICULE, vidange(null, 120_000, null, null)))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("date");
        verify(vidangeRepository, never()).save(any());
    }

    @Test
    @DisplayName("Un kilométrage absent ou négatif est refusé")
    void kilometrage_obligatoire() {
        assertThatThrownBy(() -> createUseCase.execute(VEHICULE, vidange(JOUR, null, null, null)))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> createUseCase.execute(VEHICULE, vidange(JOUR, -1, null, null)))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    @DisplayName("Une prochaine vidange datée avant la vidange est refusée")
    void date_cible_anterieure() {
        assertThatThrownBy(() -> createUseCase.execute(VEHICULE,
                vidange(JOUR, 120_000, JOUR.minusDays(1), 125_000)))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("prochaine vidange");
    }

    @Test
    @DisplayName("Un kilométrage cible inférieur à celui de la vidange est refusé")
    void kilometrage_cible_inferieur() {
        assertThatThrownBy(() -> createUseCase.execute(VEHICULE,
                vidange(JOUR, 120_000, JOUR.plusMonths(3), 119_000)))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("kilométrage");
    }

    @Test
    @DisplayName("Une cible au même kilométrage et à la même date est acceptée")
    void cible_egale_acceptee() {
        assertThatCode(() -> createUseCase.execute(VEHICULE,
                vidange(JOUR, 120_000, JOUR, 120_000))).doesNotThrowAnyException();
    }

    @Test
    @DisplayName("Un véhicule inexistant est refusé")
    void vehicule_introuvable() {
        when(vehiculeRepository.findById(VEHICULE)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> createUseCase.execute(VEHICULE,
                vidange(JOUR, 120_000, null, null)))
                .isInstanceOf(VehiculeNotFoundException.class);
        verify(vidangeRepository, never()).save(any());
    }

    @Test
    @DisplayName("L'historique d'un véhicule est restitué tel que fourni par le dépôt")
    void historique() {
        List<Vidange> historique = List.of(
                vidange(JOUR, 120_000, JOUR.plusMonths(3), 125_000),
                vidange(JOUR.minusMonths(3), 115_000, JOUR, 120_000));
        when(vidangeRepository.findByVehiculeId(VEHICULE)).thenReturn(historique);

        assertThat(getUseCase.execute(VEHICULE)).isEqualTo(historique);
    }

    @Test
    @DisplayName("Un véhicule sans vidange rend un historique vide")
    void historique_vide() {
        when(vidangeRepository.findByVehiculeId(VEHICULE)).thenReturn(List.of());

        assertThat(getUseCase.execute(VEHICULE)).isEmpty();
    }
}
