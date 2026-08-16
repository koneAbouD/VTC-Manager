package com.tmk.vtcmanager.application.usecases.indisponibilite;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.indisponibilite.Indisponibilite;
import com.tmk.vtcmanager.application.domain.indisponibilite.IndisponibiliteStatut;
import com.tmk.vtcmanager.application.domain.programmeTravail.JourSemaine;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeChauffeur;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeTravail;
import com.tmk.vtcmanager.application.exception.ChauffeurNeTravaillePasCeJourException;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.event.ChauffeurStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.ProgrammeTravailRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.EnumSet;
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
 * Congés et absences d'un chauffeur, en modèle « overlay » : le programme n'est
 * jamais modifié, le remplacement est calculé date par date. Poser un congé
 * fait bouger deux statuts — le titulaire part en congé, le remplaçant entre en
 * service — et il n'a de sens que si le titulaire travaille réellement au moins
 * un jour de la période.
 */
class IndisponibiliteChauffeurUseCasesTest {

    private static final Long INDISPO_ID = 100L;
    private static final Long TITULAIRE = 1L;
    private static final Long REMPLACANT = 9L;
    private static final LocalDate AUJOURDHUI = LocalDate.now();

    private IndisponibiliteRepository indisponibiliteRepository;
    private ProgrammeTravailRepository programmeTravailRepository;
    private ChauffeurStatutEventPublisher chauffeurStatutEventPublisher;
    private CreateIndisponibiliteUseCase createUseCase;
    private TerminerIndisponibiliteUseCase terminerUseCase;
    private DeleteIndisponibiliteUseCase deleteUseCase;
    private SynchroniserIndisponibilitesUseCase synchroniserUseCase;

    @BeforeEach
    void setUp() {
        indisponibiliteRepository = mock(IndisponibiliteRepository.class);
        programmeTravailRepository = mock(ProgrammeTravailRepository.class);
        chauffeurStatutEventPublisher = mock(ChauffeurStatutEventPublisher.class);

        when(indisponibiliteRepository.save(any())).thenAnswer(inv -> {
            Indisponibilite i = inv.getArgument(0);
            if (i.getId() == null) i.setId(INDISPO_ID);
            return i;
        });
        when(indisponibiliteRepository.findByStatut(any())).thenReturn(List.of());
        // Par défaut, le titulaire conduit tous les jours de la semaine.
        programmeCouvrant(EnumSet.allOf(JourSemaine.class));

        createUseCase = new CreateIndisponibiliteUseCase(indisponibiliteRepository,
                programmeTravailRepository, chauffeurStatutEventPublisher);
        terminerUseCase = new TerminerIndisponibiliteUseCase(
                indisponibiliteRepository, chauffeurStatutEventPublisher);
        deleteUseCase = new DeleteIndisponibiliteUseCase(
                indisponibiliteRepository, chauffeurStatutEventPublisher);
        synchroniserUseCase = new SynchroniserIndisponibilitesUseCase(
                indisponibiliteRepository, chauffeurStatutEventPublisher);
    }

    private void programmeCouvrant(Set<JourSemaine> jours) {
        when(programmeTravailRepository.findByChauffeurId(TITULAIRE)).thenReturn(Optional.of(
                ProgrammeTravail.builder()
                        .id(1L).vehiculeId(5L).nombreChauffeursAutorises(1)
                        .joursTravailSemaine(jours)
                        .chauffeurs(List.of(ProgrammeChauffeur.builder()
                                .chauffeur(Chauffeur.builder().id(TITULAIRE).build())
                                .ordreAlternance(1).build()))
                        .build()));
    }

    private Indisponibilite indispo(LocalDate debut, LocalDate fin,
                                    IndisponibiliteStatut statut, Long remplacantId) {
        return Indisponibilite.builder()
                .id(INDISPO_ID)
                .chauffeur(Chauffeur.builder().id(TITULAIRE).build())
                .chauffeurRemplacant(remplacantId == null
                        ? null : Chauffeur.builder().id(remplacantId).build())
                .dateDebut(debut).dateFin(fin).motif("Congé").statut(statut)
                .build();
    }

    @Nested
    @DisplayName("Création")
    class Creation {

        @Test
        @DisplayName("Un congé à venir est enregistré et fait recalculer les deux statuts")
        void creation_nominale() {
            Indisponibilite saved = createUseCase.execute(indispo(
                    AUJOURDHUI.plusDays(2), AUJOURDHUI.plusDays(5), null, REMPLACANT));

            assertThat(saved.getId()).isEqualTo(INDISPO_ID);
            assertThat(saved.getStatut()).isEqualTo(IndisponibiliteStatut.PLANIFIEE);
            verify(chauffeurStatutEventPublisher).publishStatutDirty(TITULAIRE);
            verify(chauffeurStatutEventPublisher).publishStatutDirty(REMPLACANT);
        }

        @Test
        @DisplayName("Un congé démarrant aujourd'hui est immédiatement en cours")
        void creation_du_jour() {
            assertThat(createUseCase.execute(indispo(
                    AUJOURDHUI, AUJOURDHUI.plusDays(3), null, REMPLACANT)).getStatut())
                    .isEqualTo(IndisponibiliteStatut.EN_COURS);
        }

        @Test
        @DisplayName("Le programme n'est jamais modifié : le remplacement reste un calcul")
        void programme_intact() {
            createUseCase.execute(indispo(
                    AUJOURDHUI.plusDays(2), AUJOURDHUI.plusDays(5), null, REMPLACANT));

            verify(programmeTravailRepository, never()).save(any());
        }

        @Test
        @DisplayName("Un congé sans remplaçant est refusé")
        void remplacant_obligatoire() {
            assertThatThrownBy(() -> createUseCase.execute(indispo(
                    AUJOURDHUI.plusDays(2), AUJOURDHUI.plusDays(5), null, null)))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessageContaining("remplaçant est obligatoire");
            verify(indisponibiliteRepository, never()).save(any());
        }

        @Test
        @DisplayName("Un congé daté du passé est refusé")
        void date_passee() {
            assertThatThrownBy(() -> createUseCase.execute(indispo(
                    AUJOURDHUI.minusDays(1), AUJOURDHUI.plusDays(5), null, REMPLACANT)))
                    .isInstanceOf(IllegalArgumentException.class);
        }

        @Test
        @DisplayName("Un congé sur des jours où le titulaire ne conduit pas est refusé")
        void aucun_jour_travaille() {
            // Le véhicule ne roule que le dimanche ; le congé porte sur deux
            // jours ouvrés : il n'a aucun effet, donc aucun sens.
            LocalDate lundi = prochainLundi();
            programmeCouvrant(EnumSet.of(JourSemaine.DIMANCHE));

            assertThatThrownBy(() -> createUseCase.execute(indispo(
                    lundi, lundi.plusDays(1), null, REMPLACANT)))
                    .isInstanceOf(ChauffeurNeTravaillePasCeJourException.class);
        }

        @Test
        @DisplayName("Un seul jour travaillé dans la période suffit")
        void un_jour_travaille_suffit() {
            LocalDate lundi = prochainLundi();
            programmeCouvrant(EnumSet.of(JourSemaine.MERCREDI));

            // Période lundi → dimanche : le mercredi est dedans.
            assertThat(createUseCase.execute(indispo(
                    lundi, lundi.plusDays(6), null, REMPLACANT))).isNotNull();
        }

        @Test
        @DisplayName("Un titulaire sans programme est refusé : il ne conduit rien")
        void sans_programme() {
            when(programmeTravailRepository.findByChauffeurId(TITULAIRE)).thenReturn(Optional.empty());

            assertThatThrownBy(() -> createUseCase.execute(indispo(
                    AUJOURDHUI.plusDays(2), AUJOURDHUI.plusDays(5), null, REMPLACANT)))
                    .isInstanceOf(ChauffeurNeTravaillePasCeJourException.class);
        }

        private LocalDate prochainLundi() {
            LocalDate date = AUJOURDHUI.plusDays(1);
            while (date.getDayOfWeek() != java.time.DayOfWeek.MONDAY) {
                date = date.plusDays(1);
            }
            return date;
        }
    }

    @Nested
    @DisplayName("Clôture et suppression")
    class Fin {

        @Test
        @DisplayName("Terminer borne la fin à aujourd'hui et rend les deux statuts au calcul")
        void cloture() {
            when(indisponibiliteRepository.findById(INDISPO_ID)).thenReturn(Optional.of(indispo(
                    AUJOURDHUI.minusDays(3), AUJOURDHUI.plusDays(10),
                    IndisponibiliteStatut.EN_COURS, REMPLACANT)));

            Indisponibilite saved = terminerUseCase.execute(INDISPO_ID);

            assertThat(saved.getStatut()).isEqualTo(IndisponibiliteStatut.TERMINEE);
            assertThat(saved.getDateFin()).isEqualTo(AUJOURDHUI);
            verify(chauffeurStatutEventPublisher).publishStatutDirty(TITULAIRE);
            verify(chauffeurStatutEventPublisher).publishStatutDirty(REMPLACANT);
        }

        @Test
        @DisplayName("Clôturer un congé inexistant est refusé")
        void cloture_introuvable() {
            when(indisponibiliteRepository.findById(INDISPO_ID)).thenReturn(Optional.empty());

            assertThatThrownBy(() -> terminerUseCase.execute(INDISPO_ID))
                    .isInstanceOf(ResourceNotFoundException.class);
        }

        @Test
        @DisplayName("La suppression efface le congé et fait recalculer les deux statuts")
        void suppression() {
            when(indisponibiliteRepository.findById(INDISPO_ID)).thenReturn(Optional.of(indispo(
                    AUJOURDHUI, AUJOURDHUI.plusDays(3),
                    IndisponibiliteStatut.EN_COURS, REMPLACANT)));

            deleteUseCase.execute(INDISPO_ID);

            verify(indisponibiliteRepository).deleteById(INDISPO_ID);
            verify(chauffeurStatutEventPublisher).publishStatutDirty(TITULAIRE);
            verify(chauffeurStatutEventPublisher).publishStatutDirty(REMPLACANT);
        }

        @Test
        @DisplayName("Supprimer un congé inexistant est refusé")
        void suppression_introuvable() {
            when(indisponibiliteRepository.findById(INDISPO_ID)).thenReturn(Optional.empty());

            assertThatThrownBy(() -> deleteUseCase.execute(INDISPO_ID))
                    .isInstanceOf(ResourceNotFoundException.class);
            verify(indisponibiliteRepository, never()).deleteById(anyLong());
        }
    }

    @Nested
    @DisplayName("Synchronisation quotidienne")
    class Synchronisation {

        @Test
        @DisplayName("Un congé dont la période a commencé passe en cours")
        void activation() {
            Indisponibilite planifiee = indispo(AUJOURDHUI, AUJOURDHUI.plusDays(3),
                    IndisponibiliteStatut.PLANIFIEE, REMPLACANT);
            when(indisponibiliteRepository.findByStatut(IndisponibiliteStatut.PLANIFIEE))
                    .thenReturn(List.of(planifiee));

            assertThat(synchroniserUseCase.execute()).isEqualTo(1);
            assertThat(planifiee.getStatut()).isEqualTo(IndisponibiliteStatut.EN_COURS);
            verify(chauffeurStatutEventPublisher).publishStatutDirty(TITULAIRE);
        }

        @Test
        @DisplayName("Un congé échu passe en terminé")
        void cloture_automatique() {
            Indisponibilite enCours = indispo(AUJOURDHUI.minusDays(10), AUJOURDHUI.minusDays(1),
                    IndisponibiliteStatut.EN_COURS, REMPLACANT);
            when(indisponibiliteRepository.findByStatut(IndisponibiliteStatut.EN_COURS))
                    .thenReturn(List.of(enCours));

            assertThat(synchroniserUseCase.execute()).isEqualTo(1);
            assertThat(enCours.getStatut()).isEqualTo(IndisponibiliteStatut.TERMINEE);
        }

        @Test
        @DisplayName("Un congé encore à venir n'est pas activé")
        void pas_encore_commence() {
            when(indisponibiliteRepository.findByStatut(IndisponibiliteStatut.PLANIFIEE))
                    .thenReturn(List.of(indispo(AUJOURDHUI.plusDays(3), AUJOURDHUI.plusDays(5),
                            IndisponibiliteStatut.PLANIFIEE, REMPLACANT)));

            assertThat(synchroniserUseCase.execute()).isZero();
            verify(indisponibiliteRepository, never()).save(any());
        }

        @Test
        @DisplayName("Un congé en cours et non échu reste en cours")
        void encore_en_cours() {
            when(indisponibiliteRepository.findByStatut(IndisponibiliteStatut.EN_COURS))
                    .thenReturn(List.of(indispo(AUJOURDHUI.minusDays(1), AUJOURDHUI.plusDays(5),
                            IndisponibiliteStatut.EN_COURS, REMPLACANT)));

            assertThat(synchroniserUseCase.execute()).isZero();
        }

        @Test
        @DisplayName("Un congé ouvert ne se clôture jamais tout seul")
        void periode_ouverte() {
            when(indisponibiliteRepository.findByStatut(IndisponibiliteStatut.EN_COURS))
                    .thenReturn(List.of(indispo(AUJOURDHUI.minusDays(30), null,
                            IndisponibiliteStatut.EN_COURS, REMPLACANT)));

            assertThat(synchroniserUseCase.execute()).isZero();
        }

        @Test
        @DisplayName("Rejouer la synchronisation ne produit plus aucun changement")
        void idempotence() {
            assertThat(synchroniserUseCase.execute()).isZero();
            assertThat(synchroniserUseCase.execute()).isZero();
            verify(indisponibiliteRepository, never()).save(any());
        }
    }
}
