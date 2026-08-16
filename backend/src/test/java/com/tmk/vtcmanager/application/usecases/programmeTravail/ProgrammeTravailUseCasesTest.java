package com.tmk.vtcmanager.application.usecases.programmeTravail;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.chauffeur.ChauffeurStatus;
import com.tmk.vtcmanager.application.domain.conditionTravail.ConditionTravail;
import com.tmk.vtcmanager.application.domain.document.CibleDocument;
import com.tmk.vtcmanager.application.domain.document.Document;
import com.tmk.vtcmanager.application.domain.document.DocumentStatut;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeChauffeur;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeTravail;
import com.tmk.vtcmanager.application.domain.programmeTravail.TypeProgrammeTravail;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.exception.ChauffeurAlreadyAssignedException;
import com.tmk.vtcmanager.application.exception.ChauffeurNotFoundException;
import com.tmk.vtcmanager.application.exception.ChauffeurPermisExpireException;
import com.tmk.vtcmanager.application.exception.ChauffeurSuspenduException;
import com.tmk.vtcmanager.application.exception.VehiculeNotFoundException;
import com.tmk.vtcmanager.application.ports.event.ChauffeurStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.event.VehiculeStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.application.ports.persistence.DocumentRepository;
import com.tmk.vtcmanager.application.ports.persistence.ProgrammeTravailRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import com.tmk.vtcmanager.application.services.IndisponibiliteNettoyageService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Configuration des chauffeurs d'un véhicule. Le use case porte les verrous
 * d'exploitation : on ne met pas au volant un chauffeur suspendu ni un chauffeur
 * dont le permis a expiré, et un chauffeur ne conduit qu'un véhicule à la fois.
 * Chaque entrée ou sortie du programme réaligne les affectations et les statuts.
 */
class ProgrammeTravailUseCasesTest {

    private static final Long VEHICULE = 5L;
    private static final Long CHAUFFEUR_A = 1L;
    private static final Long CHAUFFEUR_B = 2L;

    private ProgrammeTravailRepository programmeRepository;
    private VehiculeRepository vehiculeRepository;
    private ChauffeurRepository chauffeurRepository;
    private IndisponibiliteNettoyageService indisponibiliteNettoyageService;
    private DocumentRepository documentRepository;
    private VehiculeStatutEventPublisher statutEventPublisher;
    private ChauffeurStatutEventPublisher chauffeurStatutEventPublisher;
    private CreateProgrammeTravailUseCase createUseCase;
    private GetProgrammeTravailUseCase getUseCase;
    private InvertProgrammeTravailUseCase invertUseCase;

    @BeforeEach
    void setUp() {
        programmeRepository = mock(ProgrammeTravailRepository.class);
        vehiculeRepository = mock(VehiculeRepository.class);
        chauffeurRepository = mock(ChauffeurRepository.class);
        indisponibiliteNettoyageService = mock(IndisponibiliteNettoyageService.class);
        documentRepository = mock(DocumentRepository.class);
        statutEventPublisher = mock(VehiculeStatutEventPublisher.class);
        chauffeurStatutEventPublisher = mock(ChauffeurStatutEventPublisher.class);

        when(vehiculeRepository.findById(VEHICULE)).thenReturn(Optional.of(vehicule()));
        when(programmeRepository.findByVehiculeId(VEHICULE)).thenReturn(Optional.empty());
        when(programmeRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(chauffeurRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(chauffeurRepository.findById(anyLong())).thenAnswer(inv ->
                Optional.of(chauffeurActif(inv.getArgument(0))));
        when(documentRepository.findByCibleAndCibleId(any(), anyLong())).thenReturn(List.of());

        createUseCase = new CreateProgrammeTravailUseCase(programmeRepository, vehiculeRepository,
                chauffeurRepository, indisponibiliteNettoyageService, documentRepository,
                statutEventPublisher, chauffeurStatutEventPublisher);
        getUseCase = new GetProgrammeTravailUseCase(programmeRepository, vehiculeRepository);
        invertUseCase = new InvertProgrammeTravailUseCase(programmeRepository, vehiculeRepository);
    }

    private ConditionTravail condition(int nbChauffeurs) {
        ConditionTravail condition = new ConditionTravail();
        condition.setId(1L);
        condition.setNbChauffeurs(nbChauffeurs);
        condition.setTypeProgramme(TypeProgrammeTravail.JOURNALIER.name());
        condition.setHeureDebutService("08:00");
        condition.setHeureFinService("20:00");
        condition.setModeAlternance("MANUELLE");
        return condition;
    }

    private Vehicule vehicule() {
        return Vehicule.builder()
                .id(VEHICULE).immatriculation("AA-123-BB").conditionTravail(condition(2)).build();
    }

    private Chauffeur chauffeurActif(Long id) {
        return Chauffeur.builder()
                .id(id).nom("Kouassi").prenom("Aya").statut(ChauffeurStatus.ACTIF).build();
    }

    private ProgrammeTravail programmeAvec(Long... chauffeurIds) {
        List<ProgrammeChauffeur> chauffeurs = new ArrayList<>();
        int ordre = 1;
        for (Long id : chauffeurIds) {
            chauffeurs.add(ProgrammeChauffeur.builder()
                    .chauffeur(Chauffeur.builder().id(id).build())
                    .ordreAlternance(ordre)
                    .ordreJourSalaire(ordre)
                    .dateService(LocalDate.now())
                    .build());
            ordre++;
        }
        return ProgrammeTravail.builder().chauffeurs(chauffeurs).build();
    }

    @Nested
    @DisplayName("Configuration")
    class Configuration {

        @Test
        @DisplayName("Les chauffeurs configurés sont affectés au véhicule")
        void configuration_nominale() {
            ProgrammeTravail saved = createUseCase.execute(VEHICULE,
                    programmeAvec(CHAUFFEUR_A, CHAUFFEUR_B));

            assertThat(saved.getVehiculeId()).isEqualTo(VEHICULE);
            assertThat(saved.getChauffeurs()).hasSize(2);
            verify(chauffeurRepository, org.mockito.Mockito.times(2)).save(any(Chauffeur.class));
            verify(chauffeurStatutEventPublisher).publishStatutDirty(CHAUFFEUR_A);
            verify(chauffeurStatutEventPublisher).publishStatutDirty(CHAUFFEUR_B);
            verify(statutEventPublisher).publishStatutDirty(VEHICULE);
        }

        @Test
        @DisplayName("Le programme est réaligné sur la condition de travail du véhicule")
        void aligne_sur_la_condition() {
            ProgrammeTravail saved = createUseCase.execute(VEHICULE,
                    programmeAvec(CHAUFFEUR_A, CHAUFFEUR_B));

            assertThat(saved.getNombreChauffeursAutorises()).isEqualTo(2);
            assertThat(saved.getTypeProgramme()).isEqualTo(TypeProgrammeTravail.JOURNALIER);
            assertThat(saved.getHeureDebutService()).isEqualTo(java.time.LocalTime.of(8, 0));
        }

        @Test
        @DisplayName("Un chauffeur retiré du programme est dé-affecté et ses congés nettoyés")
        void chauffeur_retire() {
            when(programmeRepository.findByVehiculeId(VEHICULE))
                    .thenReturn(Optional.of(programmeAvec(CHAUFFEUR_A, CHAUFFEUR_B)));
            when(vehiculeRepository.findById(VEHICULE)).thenReturn(Optional.of(
                    Vehicule.builder().id(VEHICULE).conditionTravail(condition(1)).build()));

            createUseCase.execute(VEHICULE, programmeAvec(CHAUFFEUR_A));

            verify(indisponibiliteNettoyageService).nettoyerSiOrphelin(CHAUFFEUR_B);
            verify(chauffeurStatutEventPublisher).publishStatutDirty(CHAUFFEUR_B);
        }

        @Test
        @DisplayName("Un véhicule sans condition de travail ne peut pas être configuré")
        void sans_condition_de_travail() {
            when(vehiculeRepository.findById(VEHICULE))
                    .thenReturn(Optional.of(Vehicule.builder().id(VEHICULE).build()));

            assertThatThrownBy(() -> createUseCase.execute(VEHICULE, programmeAvec(CHAUFFEUR_A)))
                    .isInstanceOf(IllegalStateException.class)
                    .hasMessageContaining("condition de travail");
        }

        @Test
        @DisplayName("Un véhicule inexistant est refusé")
        void vehicule_introuvable() {
            when(vehiculeRepository.findById(VEHICULE)).thenReturn(Optional.empty());

            assertThatThrownBy(() -> createUseCase.execute(VEHICULE, programmeAvec(CHAUFFEUR_A)))
                    .isInstanceOf(VehiculeNotFoundException.class);
        }

        @Test
        @DisplayName("Une date de prise de service manquante est refusée")
        void date_service_obligatoire() {
            ProgrammeTravail programme = programmeAvec(CHAUFFEUR_A, CHAUFFEUR_B);
            programme.getChauffeurs().get(0).setDateService(null);

            assertThatThrownBy(() -> createUseCase.execute(VEHICULE, programme))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessageContaining("prise de service");
        }

        @Test
        @DisplayName("Un chauffeur inexistant est refusé")
        void chauffeur_introuvable() {
            when(chauffeurRepository.findById(CHAUFFEUR_A)).thenReturn(Optional.empty());

            assertThatThrownBy(() -> createUseCase.execute(VEHICULE,
                    programmeAvec(CHAUFFEUR_A, CHAUFFEUR_B)))
                    .isInstanceOf(ChauffeurNotFoundException.class);
        }
    }

    @Nested
    @DisplayName("Verrous d'exploitation")
    class Verrous {

        @Test
        @DisplayName("Un chauffeur suspendu ne prend pas le volant")
        void chauffeur_suspendu() {
            Chauffeur suspendu = chauffeurActif(CHAUFFEUR_A);
            suspendu.setStatut(ChauffeurStatus.SUSPENDU);
            when(chauffeurRepository.findById(CHAUFFEUR_A)).thenReturn(Optional.of(suspendu));

            assertThatThrownBy(() -> createUseCase.execute(VEHICULE,
                    programmeAvec(CHAUFFEUR_A, CHAUFFEUR_B)))
                    .isInstanceOf(ChauffeurSuspenduException.class);
            verify(programmeRepository, never()).save(any());
        }

        @Test
        @DisplayName("Un chauffeur en congé reste configurable : il sera remplacé par date")
        void chauffeur_en_conge_autorise() {
            Chauffeur enConge = chauffeurActif(CHAUFFEUR_A);
            enConge.setStatut(ChauffeurStatus.EN_CONGE);
            when(chauffeurRepository.findById(CHAUFFEUR_A)).thenReturn(Optional.of(enConge));

            assertThat(createUseCase.execute(VEHICULE, programmeAvec(CHAUFFEUR_A, CHAUFFEUR_B)))
                    .isNotNull();
        }

        @Test
        @DisplayName("Un chauffeur au permis expiré ne prend pas le volant")
        void permis_expire() {
            when(documentRepository.findByCibleAndCibleId(CibleDocument.CHAUFFEUR, CHAUFFEUR_A))
                    .thenReturn(List.of(Document.builder()
                            .id(1L).categorie(Set.of(com.tmk.vtcmanager.application.domain
                                    .chauffeur.TypePermis.B))
                            .statut(DocumentStatut.VALIDE)
                            .permanence(false)
                            .dateExpiration(LocalDate.now().minusDays(1))
                            .build()));

            assertThatThrownBy(() -> createUseCase.execute(VEHICULE,
                    programmeAvec(CHAUFFEUR_A, CHAUFFEUR_B)))
                    .isInstanceOf(ChauffeurPermisExpireException.class);
        }

        @Test
        @DisplayName("Un permis encore valide n'empêche rien")
        void permis_valide() {
            when(documentRepository.findByCibleAndCibleId(CibleDocument.CHAUFFEUR, CHAUFFEUR_A))
                    .thenReturn(List.of(Document.builder()
                            .id(1L).categorie(Set.of(com.tmk.vtcmanager.application.domain
                                    .chauffeur.TypePermis.B))
                            .statut(DocumentStatut.VALIDE)
                            .permanence(false)
                            .dateExpiration(LocalDate.now().plusYears(1))
                            .build()));

            assertThat(createUseCase.execute(VEHICULE, programmeAvec(CHAUFFEUR_A, CHAUFFEUR_B)))
                    .isNotNull();
        }

        @Test
        @DisplayName("Un chauffeur déjà au volant d'un autre véhicule est refusé")
        void deja_affecte_ailleurs() {
            Chauffeur ailleurs = chauffeurActif(CHAUFFEUR_A);
            ailleurs.assignVehicule(Vehicule.builder().id(99L).immatriculation("ZZ-999-ZZ").build());
            when(chauffeurRepository.findById(CHAUFFEUR_A)).thenReturn(Optional.of(ailleurs));

            assertThatThrownBy(() -> createUseCase.execute(VEHICULE,
                    programmeAvec(CHAUFFEUR_A, CHAUFFEUR_B)))
                    .isInstanceOf(ChauffeurAlreadyAssignedException.class);
        }

        @Test
        @DisplayName("Un chauffeur déjà affecté à CE véhicule n'est pas réaffecté")
        void deja_affecte_au_meme_vehicule() {
            Chauffeur dejaLa = chauffeurActif(CHAUFFEUR_A);
            dejaLa.assignVehicule(Vehicule.builder().id(VEHICULE).build());
            when(chauffeurRepository.findById(CHAUFFEUR_A)).thenReturn(Optional.of(dejaLa));

            createUseCase.execute(VEHICULE, programmeAvec(CHAUFFEUR_A, CHAUFFEUR_B));

            // Seul le chauffeur B est enregistré : A l'était déjà.
            verify(chauffeurRepository, org.mockito.Mockito.times(1)).save(any(Chauffeur.class));
        }
    }

    @Nested
    @DisplayName("Consultation et inversion")
    class Consultation {

        @Test
        @DisplayName("Un véhicule sans programme rend un programme par défaut")
        void programme_par_defaut() {
            ProgrammeTravail programme = getUseCase.execute(VEHICULE);

            assertThat(programme.getVehiculeId()).isEqualTo(VEHICULE);
            assertThat(programme.getChauffeurs()).isEmpty();
            // Aligné sur la condition du véhicule, qui autorise 2 chauffeurs.
            assertThat(programme.getNombreChauffeursAutorises()).isEqualTo(2);
        }

        @Test
        @DisplayName("Consulter le programme d'un véhicule inexistant est refusé")
        void vehicule_introuvable() {
            when(vehiculeRepository.findById(VEHICULE)).thenReturn(Optional.empty());

            assertThatThrownBy(() -> getUseCase.execute(VEHICULE))
                    .isInstanceOf(VehiculeNotFoundException.class);
        }

        @Test
        @DisplayName("L'inversion permute l'ordre d'alternance des deux chauffeurs")
        void inversion() {
            ProgrammeTravail programme = programmeAvec(CHAUFFEUR_A, CHAUFFEUR_B);
            programme.setVehiculeId(VEHICULE);
            programme.synchronizeWithCondition(condition(2));
            when(programmeRepository.findByVehiculeId(VEHICULE)).thenReturn(Optional.of(programme));

            ProgrammeTravail inverse = invertUseCase.execute(VEHICULE);

            assertThat(inverse.getChauffeurs()).filteredOn(
                            pc -> CHAUFFEUR_A.equals(pc.getChauffeurId()))
                    .singleElement().extracting(ProgrammeChauffeur::getOrdreAlternance).isEqualTo(2);
            assertThat(inverse.getChauffeurs()).filteredOn(
                            pc -> CHAUFFEUR_B.equals(pc.getChauffeurId()))
                    .singleElement().extracting(ProgrammeChauffeur::getOrdreAlternance).isEqualTo(1);
        }

        @Test
        @DisplayName("Inverser un programme à un seul chauffeur est refusé")
        void inversion_impossible() {
            ProgrammeTravail programme = programmeAvec(CHAUFFEUR_A);
            programme.setVehiculeId(VEHICULE);
            when(programmeRepository.findByVehiculeId(VEHICULE)).thenReturn(Optional.of(programme));

            assertThatThrownBy(() -> invertUseCase.execute(VEHICULE))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessageContaining("au moins 2 chauffeurs");
        }

        @Test
        @DisplayName("Inverser sans programme configuré est refusé")
        void inversion_sans_programme() {
            assertThatThrownBy(() -> invertUseCase.execute(VEHICULE))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessageContaining("Aucun programme");
        }
    }
}
