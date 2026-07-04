package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatus;
import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatutHistorique;
import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatutMotif;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeStatutHistoriqueRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class VehiculeStatutHistoriqueServiceTest {

    private VehiculeStatutHistoriqueRepository repository;
    private VehiculeStatutHistoriqueService service;

    @BeforeEach
    void setUp() {
        repository = mock(VehiculeStatutHistoriqueRepository.class);
        service = new VehiculeStatutHistoriqueService(repository);
    }

    @Test
    void ouvreUnePeriodeQuandAucuneEnCours() {
        when(repository.findEnCoursByVehiculeId(1L)).thenReturn(Optional.empty());

        service.enregistrerTransition(1L, VehiculeStatus.DISPONIBLE, VehiculeStatutMotif.ENTREE_FLOTTE);

        ArgumentCaptor<VehiculeStatutHistorique> captor =
                ArgumentCaptor.forClass(VehiculeStatutHistorique.class);
        verify(repository).save(captor.capture());
        VehiculeStatutHistorique creee = captor.getValue();
        assertThat(creee.getVehiculeId()).isEqualTo(1L);
        assertThat(creee.getStatut()).isEqualTo(VehiculeStatus.DISPONIBLE);
        assertThat(creee.getMotif()).isEqualTo(VehiculeStatutMotif.ENTREE_FLOTTE);
        assertThat(creee.getDateDebut()).isNotNull();
        assertThat(creee.getDateFin()).isNull();
    }

    @Test
    void clotLaPeriodeEnCoursEtEnOuvreUneNouvelleSurChangement() {
        VehiculeStatutHistorique enCours = VehiculeStatutHistorique.builder()
                .id(10L).vehiculeId(1L)
                .statut(VehiculeStatus.DISPONIBLE)
                .dateDebut(LocalDateTime.now().minusDays(3))
                .build();
        when(repository.findEnCoursByVehiculeId(1L)).thenReturn(Optional.of(enCours));

        service.enregistrerTransition(1L, VehiculeStatus.EN_SERVICE, VehiculeStatutMotif.CHAUFFEUR_AFFECTE);

        ArgumentCaptor<VehiculeStatutHistorique> captor =
                ArgumentCaptor.forClass(VehiculeStatutHistorique.class);
        verify(repository, times(2)).save(captor.capture());
        List<VehiculeStatutHistorique> saved = captor.getAllValues();

        assertThat(saved.get(0).getId()).isEqualTo(10L);
        assertThat(saved.get(0).getDateFin()).isNotNull();

        assertThat(saved.get(1).getStatut()).isEqualTo(VehiculeStatus.EN_SERVICE);
        assertThat(saved.get(1).getMotif()).isEqualTo(VehiculeStatutMotif.CHAUFFEUR_AFFECTE);
        assertThat(saved.get(1).getDateFin()).isNull();
    }

    @Test
    void neCreePasDeLigneSiMemeStatut() {
        VehiculeStatutHistorique enCours = VehiculeStatutHistorique.builder()
                .id(10L).vehiculeId(1L)
                .statut(VehiculeStatus.IMMOBILISE)
                .motif(VehiculeStatutMotif.IMMOBILISATION_PENALITE)
                .dateDebut(LocalDateTime.now().minusDays(1))
                .build();
        when(repository.findEnCoursByVehiculeId(1L)).thenReturn(Optional.of(enCours));

        service.enregistrerTransition(1L, VehiculeStatus.IMMOBILISE,
                VehiculeStatutMotif.IMMOBILISATION_PENALITE);

        verify(repository, never()).save(any());
    }

    @Test
    void metAJourLeMotifSiMemeStatutMaisMotifDifferent() {
        VehiculeStatutHistorique enCours = VehiculeStatutHistorique.builder()
                .id(10L).vehiculeId(1L)
                .statut(VehiculeStatus.IMMOBILISE)
                .motif(VehiculeStatutMotif.IMMOBILISATION_PENALITE)
                .dateDebut(LocalDateTime.now().minusDays(1))
                .build();
        when(repository.findEnCoursByVehiculeId(1L)).thenReturn(Optional.of(enCours));

        service.enregistrerTransition(1L, VehiculeStatus.IMMOBILISE,
                VehiculeStatutMotif.PANNE_OU_ACCIDENT);

        ArgumentCaptor<VehiculeStatutHistorique> captor =
                ArgumentCaptor.forClass(VehiculeStatutHistorique.class);
        verify(repository).save(captor.capture());
        assertThat(captor.getValue().getId()).isEqualTo(10L);
        assertThat(captor.getValue().getMotif()).isEqualTo(VehiculeStatutMotif.PANNE_OU_ACCIDENT);
        assertThat(captor.getValue().getDateFin()).isNull();
    }

    @Test
    void ignoreLesParametresNuls() {
        service.enregistrerTransition(null, VehiculeStatus.DISPONIBLE, null);
        service.enregistrerTransition(1L, null, null);
        verifyNoInteractions(repository);
    }
}
