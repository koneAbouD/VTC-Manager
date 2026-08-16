package com.tmk.vtcmanager.application.usecases.vehicule;

import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatus;
import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatutMotif;
import com.tmk.vtcmanager.application.exception.VehiculeNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteVehiculeRepository;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.MaintenanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import com.tmk.vtcmanager.application.services.VehiculeStatutHistoriqueService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

/**
 * Recalcul du statut d'un véhicule à partir de ses signaux métier. C'est le
 * cœur de l'état de parc : la priorité entre les signaux détermine ce que
 * l'exploitant voit, et le statut posé à la main doit résister au recalcul —
 * une voiture accidentée ne redevient pas disponible parce qu'un chauffeur lui
 * est resté affecté.
 */
class RecomputeVehiculeStatusUseCaseTest {

    private static final Long VEHICULE = 5L;

    private VehiculeRepository vehiculeRepository;
    private ChauffeurRepository chauffeurRepository;
    private MaintenanceRepository maintenanceRepository;
    private LignePenaliteRepository lignePenaliteRepository;
    private IndisponibiliteVehiculeRepository indisponibiliteVehiculeRepository;
    private VehiculeStatutHistoriqueService statutHistoriqueService;
    private RecomputeVehiculeStatusUseCase useCase;

    @BeforeEach
    void setUp() {
        vehiculeRepository = mock(VehiculeRepository.class);
        chauffeurRepository = mock(ChauffeurRepository.class);
        maintenanceRepository = mock(MaintenanceRepository.class);
        lignePenaliteRepository = mock(LignePenaliteRepository.class);
        indisponibiliteVehiculeRepository = mock(IndisponibiliteVehiculeRepository.class);
        statutHistoriqueService = mock(VehiculeStatutHistoriqueService.class);

        // Aucun signal actif par défaut : véhicule au parc, sans chauffeur.
        when(indisponibiliteVehiculeRepository.isImmobiliseAt(anyLong(), any())).thenReturn(false);
        when(lignePenaliteRepository.hasImmobilisationActiveByVehiculeId(anyLong())).thenReturn(false);
        when(maintenanceRepository.existsByVehiculeIdAndStatut(anyLong(), any())).thenReturn(false);
        when(chauffeurRepository.existsByVehiculeId(anyLong())).thenReturn(false);
        when(vehiculeRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        useCase = new RecomputeVehiculeStatusUseCase(vehiculeRepository, chauffeurRepository,
                maintenanceRepository, lignePenaliteRepository, indisponibiliteVehiculeRepository,
                statutHistoriqueService);
    }

    private Vehicule vehicule(VehiculeStatus statut, VehiculeStatus statutManuel) {
        Vehicule vehicule = Vehicule.builder()
                .id(VEHICULE).immatriculation("AA-123-BB").statut(statut).build();
        vehicule.setStatutManuel(statutManuel);
        when(vehiculeRepository.findById(VEHICULE)).thenReturn(Optional.of(vehicule));
        return vehicule;
    }

    // ── Priorité des signaux ────────────────────────────────────────────────

    @Test
    @DisplayName("Sans chauffeur ni contrainte, le véhicule est disponible")
    void aucun_signal() {
        Vehicule vehicule = vehicule(VehiculeStatus.EN_SERVICE, null);

        useCase.execute(VEHICULE);

        assertThat(vehicule.getStatut()).isEqualTo(VehiculeStatus.DISPONIBLE);
        verify(statutHistoriqueService).enregistrerTransition(
                VEHICULE, VehiculeStatus.DISPONIBLE, VehiculeStatutMotif.SANS_CHAUFFEUR);
    }

    @Test
    @DisplayName("Un chauffeur affecté met le véhicule en service")
    void chauffeur_affecte() {
        Vehicule vehicule = vehicule(VehiculeStatus.DISPONIBLE, null);
        when(chauffeurRepository.existsByVehiculeId(VEHICULE)).thenReturn(true);

        useCase.execute(VEHICULE);

        assertThat(vehicule.getStatut()).isEqualTo(VehiculeStatus.EN_SERVICE);
        verify(statutHistoriqueService).enregistrerTransition(
                VEHICULE, VehiculeStatus.EN_SERVICE, VehiculeStatutMotif.CHAUFFEUR_AFFECTE);
    }

    @Test
    @DisplayName("Une maintenance en cours l'emporte sur l'affectation d'un chauffeur")
    void maintenance_prioritaire_sur_chauffeur() {
        Vehicule vehicule = vehicule(VehiculeStatus.EN_SERVICE, null);
        when(chauffeurRepository.existsByVehiculeId(VEHICULE)).thenReturn(true);
        when(maintenanceRepository.existsByVehiculeIdAndStatut(VEHICULE, MaintenanceStatus.EN_COURS))
                .thenReturn(true);

        useCase.execute(VEHICULE);

        assertThat(vehicule.getStatut()).isEqualTo(VehiculeStatus.EN_MAINTENANCE);
        verify(statutHistoriqueService).enregistrerTransition(
                VEHICULE, VehiculeStatus.EN_MAINTENANCE, VehiculeStatutMotif.MAINTENANCE_EN_COURS);
    }

    @Test
    @DisplayName("Une immobilisation de pénalité l'emporte sur la maintenance")
    void penalite_prioritaire_sur_maintenance() {
        Vehicule vehicule = vehicule(VehiculeStatus.EN_SERVICE, null);
        when(maintenanceRepository.existsByVehiculeIdAndStatut(VEHICULE, MaintenanceStatus.EN_COURS))
                .thenReturn(true);
        when(lignePenaliteRepository.hasImmobilisationActiveByVehiculeId(VEHICULE)).thenReturn(true);

        useCase.execute(VEHICULE);

        assertThat(vehicule.getStatut()).isEqualTo(VehiculeStatus.IMMOBILISE);
        verify(statutHistoriqueService).enregistrerTransition(
                VEHICULE, VehiculeStatus.IMMOBILISE, VehiculeStatutMotif.IMMOBILISATION_PENALITE);
    }

    @Test
    @DisplayName("Une indisponibilité planifiée l'emporte sur tous les autres signaux")
    void indisponibilite_prioritaire() {
        Vehicule vehicule = vehicule(VehiculeStatus.EN_SERVICE, null);
        when(chauffeurRepository.existsByVehiculeId(VEHICULE)).thenReturn(true);
        when(maintenanceRepository.existsByVehiculeIdAndStatut(VEHICULE, MaintenanceStatus.EN_COURS))
                .thenReturn(true);
        when(lignePenaliteRepository.hasImmobilisationActiveByVehiculeId(VEHICULE)).thenReturn(true);
        when(indisponibiliteVehiculeRepository.isImmobiliseAt(VEHICULE, LocalDate.now()))
                .thenReturn(true);

        useCase.execute(VEHICULE);

        assertThat(vehicule.getStatut()).isEqualTo(VehiculeStatus.IMMOBILISE);
        verify(statutHistoriqueService).enregistrerTransition(
                VEHICULE, VehiculeStatus.IMMOBILISE,
                VehiculeStatutMotif.IMMOBILISATION_INDISPONIBILITE);
    }

    @Test
    @DisplayName("L'indisponibilité est évaluée à la date du jour")
    void indisponibilite_evaluee_aujourdhui() {
        vehicule(VehiculeStatus.DISPONIBLE, null);

        useCase.execute(VEHICULE);

        verify(indisponibiliteVehiculeRepository).isImmobiliseAt(VEHICULE, LocalDate.now());
    }

    // ── Verrou manuel ───────────────────────────────────────────────────────

    @Test
    @DisplayName("Un véhicule immobilisé à la main le reste, même avec un chauffeur affecté")
    void verrou_immobilise() {
        Vehicule vehicule = vehicule(VehiculeStatus.DISPONIBLE, VehiculeStatus.IMMOBILISE);
        when(chauffeurRepository.existsByVehiculeId(VEHICULE)).thenReturn(true);

        useCase.execute(VEHICULE);

        assertThat(vehicule.getStatut()).isEqualTo(VehiculeStatus.IMMOBILISE);
        verify(statutHistoriqueService).enregistrerTransition(
                VEHICULE, VehiculeStatus.IMMOBILISE, VehiculeStatutMotif.PANNE_OU_ACCIDENT);
    }

    @Test
    @DisplayName("Un véhicule sorti du parc y reste")
    void verrou_hors_parc() {
        Vehicule vehicule = vehicule(VehiculeStatus.DISPONIBLE, VehiculeStatus.HORS_PARC);
        when(chauffeurRepository.existsByVehiculeId(VEHICULE)).thenReturn(true);

        useCase.execute(VEHICULE);

        assertThat(vehicule.getStatut()).isEqualTo(VehiculeStatus.HORS_PARC);
        verify(statutHistoriqueService).enregistrerTransition(
                VEHICULE, VehiculeStatus.HORS_PARC, VehiculeStatutMotif.SORTIE_PARC);
    }

    // ── Économie d'écriture ─────────────────────────────────────────────────

    @Test
    @DisplayName("Un statut inchangé n'est ni réenregistré ni historisé")
    void statut_inchange() {
        vehicule(VehiculeStatus.DISPONIBLE, null);

        useCase.execute(VEHICULE);

        verify(vehiculeRepository, never()).save(any());
        verifyNoInteractions(statutHistoriqueService);
    }

    @Test
    @DisplayName("Un identifiant nul ne déclenche aucun recalcul")
    void identifiant_nul() {
        useCase.execute(null);

        verifyNoInteractions(vehiculeRepository, chauffeurRepository, maintenanceRepository,
                lignePenaliteRepository, indisponibiliteVehiculeRepository, statutHistoriqueService);
    }

    @Test
    @DisplayName("Un véhicule inexistant est refusé")
    void vehicule_introuvable() {
        when(vehiculeRepository.findById(VEHICULE)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> useCase.execute(VEHICULE))
                .isInstanceOf(VehiculeNotFoundException.class);
    }

    // ── Statut manuel : pose et levée du verrou ─────────────────────────────

    @Test
    @DisplayName("Poser IMMOBILISE ou HORS_PARC à la main verrouille le statut")
    void statut_manuel_verrouille() {
        Vehicule vehicule = Vehicule.builder().id(VEHICULE).statut(VehiculeStatus.DISPONIBLE).build();

        vehicule.appliquerStatutManuel(VehiculeStatus.IMMOBILISE);
        assertThat(vehicule.estVerrouille()).isTrue();
        assertThat(vehicule.getStatut()).isEqualTo(VehiculeStatus.IMMOBILISE);

        vehicule.appliquerStatutManuel(VehiculeStatus.HORS_PARC);
        assertThat(vehicule.estVerrouille()).isTrue();
    }

    @Test
    @DisplayName("Choisir un statut calculable lève le verrou et rend la main au recalcul")
    void statut_calculable_leve_le_verrou() {
        Vehicule vehicule = Vehicule.builder().id(VEHICULE).statut(VehiculeStatus.IMMOBILISE).build();
        vehicule.appliquerStatutManuel(VehiculeStatus.IMMOBILISE);

        vehicule.appliquerStatutManuel(VehiculeStatus.DISPONIBLE);

        assertThat(vehicule.estVerrouille()).isFalse();
        assertThat(vehicule.getStatutManuel()).isNull();
    }
}
