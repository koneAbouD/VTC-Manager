package com.tmk.vtcmanager.application.usecases.chauffeur;

import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.chauffeur.ChauffeurStatus;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeChauffeur;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeTravail;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.exception.ChauffeurNotFoundException;
import com.tmk.vtcmanager.application.exception.VehiculeNotFoundException;
import com.tmk.vtcmanager.application.ports.event.ChauffeurStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.event.VehiculeStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.ProgrammeTravailRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import com.tmk.vtcmanager.application.ports.storage.FileStoragePort;
import com.tmk.vtcmanager.application.services.IndisponibiliteNettoyageService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

/**
 * Affectation, statut et consultation d'un chauffeur. L'affectation à un
 * véhicule fait bouger deux statuts à la fois ; la dé-affectation doit en outre
 * sortir le chauffeur du programme et clôturer ses congés devenus sans objet,
 * sans quoi il continuerait à figurer au planning du véhicule.
 */
class ChauffeurUseCasesTest {

    private static final Long CHAUFFEUR = 1L;
    private static final Long VEHICULE = 5L;

    private ChauffeurRepository chauffeurRepository;
    private VehiculeRepository vehiculeRepository;
    private ProgrammeTravailRepository programmeTravailRepository;
    private IndisponibiliteRepository indisponibiliteRepository;
    private IndisponibiliteNettoyageService indisponibiliteNettoyageService;
    private VehiculeStatutEventPublisher statutEventPublisher;
    private ChauffeurStatutEventPublisher chauffeurStatutEventPublisher;
    private FileStoragePort fileStoragePort;

    private AssignVehiculeToChauffeurUseCase assignUseCase;
    private UnassignVehiculeFromChauffeurUseCase unassignUseCase;
    private RecomputeChauffeurStatusUseCase recomputeUseCase;
    private DeleteChauffeurUseCase deleteUseCase;
    private GetAllChauffeursUseCase getAllUseCase;
    private GetChauffeurByIdUseCase getByIdUseCase;

    @BeforeEach
    void setUp() {
        chauffeurRepository = mock(ChauffeurRepository.class);
        vehiculeRepository = mock(VehiculeRepository.class);
        programmeTravailRepository = mock(ProgrammeTravailRepository.class);
        indisponibiliteRepository = mock(IndisponibiliteRepository.class);
        indisponibiliteNettoyageService = mock(IndisponibiliteNettoyageService.class);
        statutEventPublisher = mock(VehiculeStatutEventPublisher.class);
        chauffeurStatutEventPublisher = mock(ChauffeurStatutEventPublisher.class);
        fileStoragePort = mock(FileStoragePort.class);

        when(chauffeurRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(vehiculeRepository.findById(VEHICULE))
                .thenReturn(Optional.of(Vehicule.builder().id(VEHICULE).build()));
        when(programmeTravailRepository.findByVehiculeId(anyLong())).thenReturn(Optional.empty());
        when(programmeTravailRepository.findByChauffeurId(anyLong())).thenReturn(Optional.empty());
        when(indisponibiliteRepository.isEnCongeAt(anyLong(), any())).thenReturn(false);
        when(indisponibiliteRepository.isRemplacantActifAt(anyLong(), any())).thenReturn(false);
        when(fileStoragePort.presignedUrl(anyString(), anyInt())).thenReturn("https://minio/photo");

        assignUseCase = new AssignVehiculeToChauffeurUseCase(chauffeurRepository, vehiculeRepository,
                statutEventPublisher, chauffeurStatutEventPublisher);
        unassignUseCase = new UnassignVehiculeFromChauffeurUseCase(chauffeurRepository,
                vehiculeRepository, programmeTravailRepository, indisponibiliteNettoyageService,
                statutEventPublisher, chauffeurStatutEventPublisher);
        recomputeUseCase = new RecomputeChauffeurStatusUseCase(
                chauffeurRepository, indisponibiliteRepository);
        deleteUseCase = new DeleteChauffeurUseCase(chauffeurRepository);
        getAllUseCase = new GetAllChauffeursUseCase(chauffeurRepository, fileStoragePort);
        getByIdUseCase = new GetChauffeurByIdUseCase(chauffeurRepository,
                programmeTravailRepository, fileStoragePort);
    }

    private Chauffeur chauffeur(ChauffeurStatus statut, Vehicule vehicule) {
        Chauffeur chauffeur = Chauffeur.builder()
                .id(CHAUFFEUR).nom("Kouassi").prenom("Aya").statut(statut).vehicule(vehicule).build();
        when(chauffeurRepository.findById(CHAUFFEUR)).thenReturn(Optional.of(chauffeur));
        return chauffeur;
    }

    @Nested
    @DisplayName("Affectation à un véhicule")
    class Affectation {

        @Test
        @DisplayName("L'affectation lie le chauffeur au véhicule et recalcule les deux statuts")
        void affectation_nominale() {
            Chauffeur chauffeur = chauffeur(ChauffeurStatus.ACTIF, null);

            Chauffeur saved = assignUseCase.execute(CHAUFFEUR, VEHICULE);

            assertThat(saved.getVehicule().getId()).isEqualTo(VEHICULE);
            verify(statutEventPublisher).publishStatutDirty(VEHICULE);
            verify(chauffeurStatutEventPublisher).publishStatutDirty(CHAUFFEUR);
            assertThat(chauffeur.getVehicule()).isNotNull();
        }

        @Test
        @DisplayName("Un chauffeur inexistant est refusé")
        void chauffeur_introuvable() {
            when(chauffeurRepository.findById(CHAUFFEUR)).thenReturn(Optional.empty());

            assertThatThrownBy(() -> assignUseCase.execute(CHAUFFEUR, VEHICULE))
                    .isInstanceOf(ChauffeurNotFoundException.class);
            verifyNoInteractions(statutEventPublisher, chauffeurStatutEventPublisher);
        }

        @Test
        @DisplayName("Un véhicule inexistant est refusé")
        void vehicule_introuvable() {
            chauffeur(ChauffeurStatus.ACTIF, null);
            when(vehiculeRepository.findById(VEHICULE)).thenReturn(Optional.empty());

            assertThatThrownBy(() -> assignUseCase.execute(CHAUFFEUR, VEHICULE))
                    .isInstanceOf(VehiculeNotFoundException.class);
            verify(chauffeurRepository, never()).save(any());
        }
    }

    @Nested
    @DisplayName("Dé-affectation")
    class Deaffectation {

        @Test
        @DisplayName("Le chauffeur perd son véhicule et ses congés orphelins sont nettoyés")
        void deaffectation_nominale() {
            chauffeur(ChauffeurStatus.EN_SERVICE, Vehicule.builder().id(VEHICULE).build());

            Chauffeur saved = unassignUseCase.execute(CHAUFFEUR);

            assertThat(saved.getVehicule()).isNull();
            verify(indisponibiliteNettoyageService).nettoyerSiOrphelin(CHAUFFEUR);
            verify(statutEventPublisher).publishStatutDirty(VEHICULE);
            verify(chauffeurStatutEventPublisher).publishStatutDirty(CHAUFFEUR);
        }

        @Test
        @DisplayName("Le chauffeur est retiré du programme du véhicule")
        void retire_du_programme() {
            chauffeur(ChauffeurStatus.EN_SERVICE, Vehicule.builder().id(VEHICULE).build());
            ProgrammeTravail programme = ProgrammeTravail.builder()
                    .id(1L).vehiculeId(VEHICULE)
                    .chauffeurs(new ArrayList<>(List.of(
                            ProgrammeChauffeur.builder()
                                    .chauffeur(Chauffeur.builder().id(CHAUFFEUR).build()).build(),
                            ProgrammeChauffeur.builder()
                                    .chauffeur(Chauffeur.builder().id(2L).build()).build())))
                    .build();
            when(programmeTravailRepository.findByVehiculeId(VEHICULE))
                    .thenReturn(Optional.of(programme));

            unassignUseCase.execute(CHAUFFEUR);

            assertThat(programme.getChauffeurs()).extracting(ProgrammeChauffeur::getChauffeurId)
                    .containsExactly(2L);
            verify(programmeTravailRepository).save(programme);
        }

        @Test
        @DisplayName("Un chauffeur sans véhicule est traité sans erreur")
        void sans_vehicule() {
            chauffeur(ChauffeurStatus.ACTIF, null);

            assertThat(unassignUseCase.execute(CHAUFFEUR).getVehicule()).isNull();
            verify(programmeTravailRepository, never()).findByVehiculeId(anyLong());
        }

        @Test
        @DisplayName("Un chauffeur inexistant est refusé")
        void introuvable() {
            when(chauffeurRepository.findById(CHAUFFEUR)).thenReturn(Optional.empty());

            assertThatThrownBy(() -> unassignUseCase.execute(CHAUFFEUR))
                    .isInstanceOf(ChauffeurNotFoundException.class);
        }
    }

    @Nested
    @DisplayName("Recalcul du statut")
    class Statut {

        @Test
        @DisplayName("Un chauffeur affecté à un véhicule est en service")
        void affecte_en_service() {
            Chauffeur chauffeur = chauffeur(ChauffeurStatus.ACTIF,
                    Vehicule.builder().id(VEHICULE).build());

            recomputeUseCase.execute(CHAUFFEUR);

            assertThat(chauffeur.getStatut()).isEqualTo(ChauffeurStatus.EN_SERVICE);
            verify(chauffeurRepository).save(chauffeur);
        }

        @Test
        @DisplayName("Un remplaçant actif du jour est en service, même sans véhicule attitré")
        void remplacant_en_service() {
            Chauffeur chauffeur = chauffeur(ChauffeurStatus.ACTIF, null);
            when(indisponibiliteRepository.isRemplacantActifAt(CHAUFFEUR, LocalDate.now()))
                    .thenReturn(true);

            recomputeUseCase.execute(CHAUFFEUR);

            assertThat(chauffeur.getStatut()).isEqualTo(ChauffeurStatus.EN_SERVICE);
        }

        @Test
        @DisplayName("Un chauffeur en congé aujourd'hui passe en congé")
        void en_conge() {
            Chauffeur chauffeur = chauffeur(ChauffeurStatus.EN_SERVICE,
                    Vehicule.builder().id(VEHICULE).build());
            when(indisponibiliteRepository.isEnCongeAt(CHAUFFEUR, LocalDate.now())).thenReturn(true);

            recomputeUseCase.execute(CHAUFFEUR);

            assertThat(chauffeur.getStatut()).isEqualTo(ChauffeurStatus.EN_CONGE);
        }

        @Test
        @DisplayName("Un chauffeur suspendu à la main le reste, même affecté")
        void suspension_verrouillante() {
            Chauffeur chauffeur = chauffeur(ChauffeurStatus.ACTIF,
                    Vehicule.builder().id(VEHICULE).build());
            chauffeur.appliquerStatutManuel(ChauffeurStatus.SUSPENDU);

            recomputeUseCase.execute(CHAUFFEUR);

            assertThat(chauffeur.getStatut()).isEqualTo(ChauffeurStatus.SUSPENDU);
            assertThat(chauffeur.getDateSuspension()).isEqualTo(LocalDate.now());
        }

        @Test
        @DisplayName("Un statut calculable lève le verrou manuel")
        void statut_calculable_leve_le_verrou() {
            Chauffeur chauffeur = chauffeur(ChauffeurStatus.SUSPENDU, null);
            chauffeur.appliquerStatutManuel(ChauffeurStatus.SUSPENDU);

            chauffeur.appliquerStatutManuel(ChauffeurStatus.ACTIF);

            assertThat(chauffeur.estVerrouille()).isFalse();
            assertThat(chauffeur.getDateSuspension()).isNull();
        }

        @Test
        @DisplayName("Un statut inchangé n'est pas réenregistré")
        void statut_inchange() {
            chauffeur(ChauffeurStatus.ACTIF, null);

            recomputeUseCase.execute(CHAUFFEUR);

            verify(chauffeurRepository, never()).save(any());
        }

        @Test
        @DisplayName("Un identifiant nul ne déclenche aucun recalcul")
        void identifiant_nul() {
            recomputeUseCase.execute(null);

            verifyNoInteractions(chauffeurRepository, indisponibiliteRepository);
        }

        @Test
        @DisplayName("Un chauffeur inexistant est refusé")
        void introuvable() {
            when(chauffeurRepository.findById(CHAUFFEUR)).thenReturn(Optional.empty());

            assertThatThrownBy(() -> recomputeUseCase.execute(CHAUFFEUR))
                    .isInstanceOf(ChauffeurNotFoundException.class);
        }
    }

    @Nested
    @DisplayName("Consultation et suppression")
    class Consultation {

        @Test
        @DisplayName("La photo est servie par une URL signée temporaire")
        void url_signee() {
            Chauffeur avecPhoto = Chauffeur.builder()
                    .id(CHAUFFEUR).photoUrl("chauffeurs/photos/abc.jpg").build();
            when(chauffeurRepository.findAll()).thenReturn(List.of(avecPhoto));

            assertThat(getAllUseCase.execute()).singleElement()
                    .extracting(Chauffeur::getPhotoPresignedUrl).isEqualTo("https://minio/photo");
        }

        @Test
        @DisplayName("Un chauffeur sans photo n'appelle pas le stockage")
        void sans_photo() {
            when(chauffeurRepository.findAll()).thenReturn(List.of(
                    Chauffeur.builder().id(CHAUFFEUR).photoUrl("  ").build()));

            getAllUseCase.execute();

            verify(fileStoragePort, never()).presignedUrl(anyString(), anyInt());
        }

        @Test
        @DisplayName("La page filtrée conserve la signature des photos")
        void page_filtree() {
            when(chauffeurRepository.findPage(ChauffeurStatus.ACTIF, 0, 20))
                    .thenReturn(new PageResult<>(List.of(Chauffeur.builder()
                            .id(CHAUFFEUR).photoUrl("chauffeurs/photos/abc.jpg").build()),
                            0, 20, 1));

            PageResult<Chauffeur> page = getAllUseCase.executePage(ChauffeurStatus.ACTIF, 0, 20);

            assertThat(page.content()).singleElement()
                    .extracting(Chauffeur::getPhotoPresignedUrl).isEqualTo("https://minio/photo");
        }

        @Test
        @DisplayName("La fiche d'un chauffeur porte son programme de travail")
        void fiche_avec_programme() {
            chauffeur(ChauffeurStatus.EN_SERVICE, Vehicule.builder().id(VEHICULE).build());
            ProgrammeTravail programme = ProgrammeTravail.builder().id(1L).vehiculeId(VEHICULE).build();
            when(programmeTravailRepository.findByChauffeurId(CHAUFFEUR))
                    .thenReturn(Optional.of(programme));

            GetChauffeurByIdUseCase.Result resultat = getByIdUseCase.execute(CHAUFFEUR);

            assertThat(resultat.chauffeur().getId()).isEqualTo(CHAUFFEUR);
            assertThat(resultat.programmeTravail()).isEqualTo(programme);
        }

        @Test
        @DisplayName("Un chauffeur sans programme rend une fiche sans planning")
        void fiche_sans_programme() {
            chauffeur(ChauffeurStatus.ACTIF, null);

            assertThat(getByIdUseCase.execute(CHAUFFEUR).programmeTravail()).isNull();
        }

        @Test
        @DisplayName("Consulter une fiche inexistante est refusé")
        void fiche_introuvable() {
            when(chauffeurRepository.findById(CHAUFFEUR)).thenReturn(Optional.empty());

            assertThatThrownBy(() -> getByIdUseCase.execute(CHAUFFEUR))
                    .isInstanceOf(ChauffeurNotFoundException.class);
        }

        @Test
        @DisplayName("La suppression vérifie d'abord l'existence")
        void suppression() {
            chauffeur(ChauffeurStatus.ACTIF, null);

            deleteUseCase.execute(CHAUFFEUR);

            verify(chauffeurRepository).deleteById(CHAUFFEUR);
        }

        @Test
        @DisplayName("Supprimer un chauffeur inexistant est refusé")
        void suppression_introuvable() {
            when(chauffeurRepository.findById(CHAUFFEUR)).thenReturn(Optional.empty());

            assertThatThrownBy(() -> deleteUseCase.execute(CHAUFFEUR))
                    .isInstanceOf(ChauffeurNotFoundException.class);
            verify(chauffeurRepository, never()).deleteById(anyLong());
        }
    }
}
