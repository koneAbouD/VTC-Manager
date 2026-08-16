package com.tmk.vtcmanager.application.usecases.indisponibiliteVehicule;

import com.tmk.vtcmanager.application.domain.indisponibilite.IndisponibiliteStatut;
import com.tmk.vtcmanager.application.domain.indisponibiliteVehicule.IndisponibiliteVehicule;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.event.VehiculeStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteVehiculeRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

/**
 * Immobilisation d'un véhicule hors atelier (accident, panne longue, saisie
 * administrative). Pendant la période, le véhicule ne doit générer ni recette,
 * ni cotisation, ni pénalité — d'où le recalcul du statut à chaque écriture.
 *
 * <p>Les jours déjà écoulés d'une immobilisation en cours ne se réécrivent
 * jamais : les recettes de ces jours-là ont déjà été (ou non) générées en
 * conséquence.</p>
 */
class IndisponibiliteVehiculeUseCasesTest {

    private static final Long INDISPO_ID = 200L;
    private static final Long VEHICULE_ID = 5L;
    private static final LocalDate AUJOURDHUI = LocalDate.now();

    private IndisponibiliteVehiculeRepository repository;
    private VehiculeStatutEventPublisher statutEventPublisher;
    private CreateIndisponibiliteVehiculeUseCase createUseCase;
    private UpdateIndisponibiliteVehiculeUseCase updateUseCase;
    private TerminerIndisponibiliteVehiculeUseCase terminerUseCase;

    @BeforeEach
    void setUp() {
        repository = mock(IndisponibiliteVehiculeRepository.class);
        statutEventPublisher = mock(VehiculeStatutEventPublisher.class);
        when(repository.save(any())).thenAnswer(inv -> {
            IndisponibiliteVehicule i = inv.getArgument(0);
            if (i.getId() == null) i.setId(INDISPO_ID);
            return i;
        });

        createUseCase = new CreateIndisponibiliteVehiculeUseCase(repository, statutEventPublisher);
        updateUseCase = new UpdateIndisponibiliteVehiculeUseCase(repository, statutEventPublisher);
        terminerUseCase = new TerminerIndisponibiliteVehiculeUseCase(repository, statutEventPublisher);
    }

    private IndisponibiliteVehicule indispo(LocalDate debut, LocalDate fin,
                                            IndisponibiliteStatut statut) {
        return IndisponibiliteVehicule.builder()
                .id(INDISPO_ID)
                .vehicule(Vehicule.builder().id(VEHICULE_ID).build())
                .dateDebut(debut).dateFin(fin).motif("Accident").statut(statut)
                .build();
    }

    @Nested
    @DisplayName("Création")
    class Creation {

        @Test
        @DisplayName("Une immobilisation à venir est enregistrée et le statut du véhicule recalculé")
        void creation_nominale() {
            IndisponibiliteVehicule saved = createUseCase.execute(
                    indispo(AUJOURDHUI.plusDays(2), AUJOURDHUI.plusDays(10), null));

            assertThat(saved.getId()).isEqualTo(INDISPO_ID);
            assertThat(saved.getStatut()).isEqualTo(IndisponibiliteStatut.PLANIFIEE);
            verify(statutEventPublisher).publishStatutDirty(VEHICULE_ID);
        }

        @Test
        @DisplayName("Une immobilisation démarrant aujourd'hui est immédiatement en cours")
        void creation_du_jour() {
            IndisponibiliteVehicule saved = createUseCase.execute(
                    indispo(AUJOURDHUI, AUJOURDHUI.plusDays(5), null));

            assertThat(saved.getStatut()).isEqualTo(IndisponibiliteStatut.EN_COURS);
        }

        @Test
        @DisplayName("Une immobilisation sans date de fin reste ouverte")
        void periode_ouverte() {
            IndisponibiliteVehicule saved = createUseCase.execute(
                    indispo(AUJOURDHUI, null, null));

            assertThat(saved.getDateFin()).isNull();
            assertThat(saved.getStatut()).isEqualTo(IndisponibiliteStatut.EN_COURS);
        }

        @Test
        @DisplayName("Une immobilisation datée du passé est refusée")
        void date_passee_refusee() {
            assertThatThrownBy(() -> createUseCase.execute(
                    indispo(AUJOURDHUI.minusDays(1), AUJOURDHUI.plusDays(5), null)))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessageContaining("antérieure à aujourd'hui");
            verify(repository, never()).save(any());
        }

        @Test
        @DisplayName("Une date de fin antérieure au début est refusée")
        void dates_incoherentes() {
            assertThatThrownBy(() -> createUseCase.execute(
                    indispo(AUJOURDHUI.plusDays(5), AUJOURDHUI.plusDays(2), null)))
                    .isInstanceOf(IllegalArgumentException.class);
        }

        @Test
        @DisplayName("Une immobilisation sans véhicule est refusée")
        void sans_vehicule() {
            IndisponibiliteVehicule sansVehicule = indispo(AUJOURDHUI, AUJOURDHUI.plusDays(5), null);
            sansVehicule.setVehicule(null);

            assertThatThrownBy(() -> createUseCase.execute(sansVehicule))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessageContaining("véhicule est obligatoire");
            verifyNoInteractions(statutEventPublisher);
        }
    }

    @Nested
    @DisplayName("Modification")
    class Modification {

        private void enBase(IndisponibiliteVehicule existante) {
            when(repository.findById(INDISPO_ID)).thenReturn(Optional.of(existante));
        }

        @Test
        @DisplayName("Une immobilisation planifiée se déplace librement dans le futur")
        void deplacement_futur() {
            enBase(indispo(AUJOURDHUI.plusDays(2), AUJOURDHUI.plusDays(5),
                    IndisponibiliteStatut.PLANIFIEE));

            IndisponibiliteVehicule saved = updateUseCase.execute(INDISPO_ID,
                    indispo(AUJOURDHUI.plusDays(4), AUJOURDHUI.plusDays(9), null));

            assertThat(saved.getDateDebut()).isEqualTo(AUJOURDHUI.plusDays(4));
            assertThat(saved.getDateFin()).isEqualTo(AUJOURDHUI.plusDays(9));
            verify(statutEventPublisher).publishStatutDirty(VEHICULE_ID);
        }

        @Test
        @DisplayName("Le début d'une immobilisation en cours n'est jamais réécrit")
        void debut_en_cours_fige() {
            LocalDate debutReel = AUJOURDHUI.minusDays(3);
            enBase(indispo(debutReel, AUJOURDHUI.plusDays(5), IndisponibiliteStatut.EN_COURS));

            IndisponibiliteVehicule saved = updateUseCase.execute(INDISPO_ID,
                    indispo(AUJOURDHUI, AUJOURDHUI.plusDays(8), null));

            // Les trois jours déjà immobilisés restent immobilisés.
            assertThat(saved.getDateDebut()).isEqualTo(debutReel);
            assertThat(saved.getDateFin()).isEqualTo(AUJOURDHUI.plusDays(8));
        }

        @Test
        @DisplayName("Une immobilisation en cours ne peut pas se terminer dans le passé")
        void fin_dans_le_passe_refusee() {
            enBase(indispo(AUJOURDHUI.minusDays(3), AUJOURDHUI.plusDays(5),
                    IndisponibiliteStatut.EN_COURS));

            assertThatThrownBy(() -> updateUseCase.execute(INDISPO_ID,
                    indispo(AUJOURDHUI.minusDays(3), AUJOURDHUI.minusDays(1), null)))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessageContaining("antérieure à aujourd'hui");
        }

        @Test
        @DisplayName("Une immobilisation planifiée ne se déplace pas dans le passé")
        void planifiee_vers_le_passe_refusee() {
            enBase(indispo(AUJOURDHUI.plusDays(2), AUJOURDHUI.plusDays(5),
                    IndisponibiliteStatut.PLANIFIEE));

            assertThatThrownBy(() -> updateUseCase.execute(INDISPO_ID,
                    indispo(AUJOURDHUI.minusDays(1), AUJOURDHUI.plusDays(5), null)))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessageContaining("date passée");
        }

        @Test
        @DisplayName("Une immobilisation terminée ou annulée ne se modifie plus")
        void statuts_finaux_verrouilles() {
            enBase(indispo(AUJOURDHUI.minusDays(10), AUJOURDHUI.minusDays(2),
                    IndisponibiliteStatut.TERMINEE));
            assertThatThrownBy(() -> updateUseCase.execute(INDISPO_ID,
                    indispo(AUJOURDHUI, AUJOURDHUI.plusDays(5), null)))
                    .isInstanceOf(IllegalArgumentException.class);

            enBase(indispo(AUJOURDHUI.plusDays(2), AUJOURDHUI.plusDays(5),
                    IndisponibiliteStatut.ANNULEE));
            assertThatThrownBy(() -> updateUseCase.execute(INDISPO_ID,
                    indispo(AUJOURDHUI.plusDays(2), AUJOURDHUI.plusDays(5), null)))
                    .isInstanceOf(IllegalArgumentException.class);
        }

        @Test
        @DisplayName("Une modification sans véhicule est refusée")
        void sans_vehicule() {
            enBase(indispo(AUJOURDHUI.plusDays(2), AUJOURDHUI.plusDays(5),
                    IndisponibiliteStatut.PLANIFIEE));
            IndisponibiliteVehicule sansVehicule =
                    indispo(AUJOURDHUI.plusDays(3), AUJOURDHUI.plusDays(6), null);
            sansVehicule.setVehicule(null);

            assertThatThrownBy(() -> updateUseCase.execute(INDISPO_ID, sansVehicule))
                    .isInstanceOf(IllegalArgumentException.class);
        }

        @Test
        @DisplayName("Une immobilisation inexistante est refusée")
        void introuvable() {
            when(repository.findById(INDISPO_ID)).thenReturn(Optional.empty());

            assertThatThrownBy(() -> updateUseCase.execute(INDISPO_ID,
                    indispo(AUJOURDHUI, AUJOURDHUI.plusDays(5), null)))
                    .isInstanceOf(ResourceNotFoundException.class);
        }
    }

    @Nested
    @DisplayName("Clôture anticipée")
    class Cloture {

        @Test
        @DisplayName("Terminer borne la fin à aujourd'hui et rend le véhicule dès demain")
        void cloture_anticipee() {
            when(repository.findById(INDISPO_ID)).thenReturn(Optional.of(
                    indispo(AUJOURDHUI.minusDays(3), AUJOURDHUI.plusDays(10),
                            IndisponibiliteStatut.EN_COURS)));

            IndisponibiliteVehicule saved = terminerUseCase.execute(INDISPO_ID);

            assertThat(saved.getStatut()).isEqualTo(IndisponibiliteStatut.TERMINEE);
            assertThat(saved.getDateFin()).isEqualTo(AUJOURDHUI);
            verify(statutEventPublisher).publishStatutDirty(VEHICULE_ID);
        }

        @Test
        @DisplayName("Une fin déjà passée n'est pas repoussée")
        void fin_passee_conservee() {
            LocalDate finReelle = AUJOURDHUI.minusDays(2);
            when(repository.findById(INDISPO_ID)).thenReturn(Optional.of(
                    indispo(AUJOURDHUI.minusDays(10), finReelle, IndisponibiliteStatut.EN_COURS)));

            assertThat(terminerUseCase.execute(INDISPO_ID).getDateFin()).isEqualTo(finReelle);
        }

        @Test
        @DisplayName("Une immobilisation ouverte est bornée à aujourd'hui")
        void periode_ouverte_bornee() {
            when(repository.findById(INDISPO_ID)).thenReturn(Optional.of(
                    indispo(AUJOURDHUI.minusDays(5), null, IndisponibiliteStatut.EN_COURS)));

            assertThat(terminerUseCase.execute(INDISPO_ID).getDateFin()).isEqualTo(AUJOURDHUI);
        }

        @Test
        @DisplayName("Une immobilisation inexistante est refusée")
        void introuvable() {
            when(repository.findById(INDISPO_ID)).thenReturn(Optional.empty());

            assertThatThrownBy(() -> terminerUseCase.execute(INDISPO_ID))
                    .isInstanceOf(ResourceNotFoundException.class);
        }
    }
}
