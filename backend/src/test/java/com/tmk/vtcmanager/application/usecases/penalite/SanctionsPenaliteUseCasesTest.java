package com.tmk.vtcmanager.application.usecases.penalite;

import com.tmk.vtcmanager.application.domain.conditionTravail.TypePenalite;
import com.tmk.vtcmanager.application.domain.conditionTravail.TypeSanction;
import com.tmk.vtcmanager.application.domain.penalite.EncaissementPenalite;
import com.tmk.vtcmanager.application.domain.penalite.LignePenalite;
import com.tmk.vtcmanager.application.domain.penalite.StatutLignePenalite;
import com.tmk.vtcmanager.application.exception.LignePenaliteDejaTermineeException;
import com.tmk.vtcmanager.application.exception.LignePenaliteNonDemarrableException;
import com.tmk.vtcmanager.application.exception.LignePenaliteNonExecutableException;
import com.tmk.vtcmanager.application.exception.LignePenaliteNonLevableException;
import com.tmk.vtcmanager.application.exception.LignePenaliteNonNotifiableException;
import com.tmk.vtcmanager.application.exception.LignePenaliteNotFoundException;
import com.tmk.vtcmanager.application.ports.event.VehiculeStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
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
 * Exécution des sanctions : buzzer, avertissement, immobilisation, et
 * annulation. Chaque action n'est permise que sur le type de sanction qui lui
 * correspond et depuis le bon statut — sonner le buzzer d'une amende ou lever
 * une immobilisation jamais démarrée n'a aucun sens.
 *
 * <p>L'immobilisation est la seule à toucher l'état du parc : elle doit
 * déclencher le recalcul du statut du véhicule dans les deux sens.
 */
class SanctionsPenaliteUseCasesTest {

    private static final Long PENALITE_ID = 700L;
    private static final Long VEHICULE_ID = 5L;

    private LignePenaliteRepository lignePenaliteRepository;
    private VehiculeStatutEventPublisher statutEventPublisher;
    private ExecuterBuzzerUseCase buzzerUseCase;
    private NotifierAvertissementUseCase avertissementUseCase;
    private DemarrerImmobilisationUseCase demarrerUseCase;
    private LeverImmobilisationUseCase leverUseCase;
    private AnnulerLignePenaliteUseCase annulerUseCase;

    @BeforeEach
    void setUp() {
        lignePenaliteRepository = mock(LignePenaliteRepository.class);
        statutEventPublisher = mock(VehiculeStatutEventPublisher.class);

        buzzerUseCase = new ExecuterBuzzerUseCase(lignePenaliteRepository);
        avertissementUseCase = new NotifierAvertissementUseCase(lignePenaliteRepository);
        demarrerUseCase = new DemarrerImmobilisationUseCase(lignePenaliteRepository, statutEventPublisher);
        leverUseCase = new LeverImmobilisationUseCase(lignePenaliteRepository, statutEventPublisher);
        annulerUseCase = new AnnulerLignePenaliteUseCase(lignePenaliteRepository);
    }

    private LignePenalite penalite(TypeSanction sanction, StatutLignePenalite statut, int encaisse) {
        return LignePenalite.builder()
                .id(PENALITE_ID).vehiculeId(VEHICULE_ID).chauffeurId(1L)
                .typePenalite(TypePenalite.RECETTE_NON_VERSEE)
                .typeSanction(sanction)
                .montant(BigDecimal.valueOf(5_000))
                .montantEncaisse(BigDecimal.valueOf(encaisse))
                .dureeSanctionSecondes(30).dureeImmobilisationMinutes(60)
                .dateFaute(LocalDate.of(2026, 4, 6))
                .statut(statut).encaissements(new ArrayList<>())
                .build();
    }

    private void enBase(LignePenalite ligne) {
        when(lignePenaliteRepository.findById(PENALITE_ID)).thenReturn(Optional.of(ligne));
    }

    @Nested
    @DisplayName("Buzzer")
    class Buzzer {

        @Test
        @DisplayName("Une sanction buzzer en attente s'exécute")
        void buzzer_execute() {
            enBase(penalite(TypeSanction.BUZZER, StatutLignePenalite.EN_ATTENTE, 0));

            buzzerUseCase.executer(PENALITE_ID);

            verify(lignePenaliteRepository).updateStatut(PENALITE_ID, StatutLignePenalite.EXECUTEE);
        }

        @Test
        @DisplayName("Le buzzer ne s'applique pas à une autre sanction")
        void buzzer_sur_amende() {
            enBase(penalite(TypeSanction.AMENDE, StatutLignePenalite.EN_ATTENTE, 0));

            assertThatThrownBy(() -> buzzerUseCase.executer(PENALITE_ID))
                    .isInstanceOf(LignePenaliteNonExecutableException.class);
            verify(lignePenaliteRepository, never()).updateStatut(anyLong(), any());
        }

        @Test
        @DisplayName("Un buzzer déjà exécuté ne se rejoue pas")
        void buzzer_deja_execute() {
            enBase(penalite(TypeSanction.BUZZER, StatutLignePenalite.EXECUTEE, 0));

            assertThatThrownBy(() -> buzzerUseCase.executer(PENALITE_ID))
                    .isInstanceOf(LignePenaliteNonExecutableException.class);
        }

        @Test
        @DisplayName("Une pénalité inexistante est refusée")
        void introuvable() {
            when(lignePenaliteRepository.findById(PENALITE_ID)).thenReturn(Optional.empty());

            assertThatThrownBy(() -> buzzerUseCase.executer(PENALITE_ID))
                    .isInstanceOf(LignePenaliteNotFoundException.class);
        }
    }

    @Nested
    @DisplayName("Avertissement")
    class Avertissement {

        @Test
        @DisplayName("Un avertissement en attente est notifié")
        void avertissement_notifie() {
            enBase(penalite(TypeSanction.AVERTISSEMENT, StatutLignePenalite.EN_ATTENTE, 0));

            avertissementUseCase.executer(PENALITE_ID);

            verify(lignePenaliteRepository).updateStatut(PENALITE_ID, StatutLignePenalite.NOTIFIEE);
        }

        @Test
        @DisplayName("Notifier ne s'applique pas à une immobilisation")
        void avertissement_sur_immobilisation() {
            enBase(penalite(TypeSanction.IMMOBILISATION, StatutLignePenalite.EN_ATTENTE, 0));

            assertThatThrownBy(() -> avertissementUseCase.executer(PENALITE_ID))
                    .isInstanceOf(LignePenaliteNonNotifiableException.class);
        }

        @Test
        @DisplayName("Un avertissement déjà notifié ne se renotifie pas")
        void deja_notifie() {
            enBase(penalite(TypeSanction.AVERTISSEMENT, StatutLignePenalite.NOTIFIEE, 0));

            assertThatThrownBy(() -> avertissementUseCase.executer(PENALITE_ID))
                    .isInstanceOf(LignePenaliteNonNotifiableException.class);
        }
    }

    @Nested
    @DisplayName("Immobilisation")
    class Immobilisation {

        @Test
        @DisplayName("Démarrer l'immobilisation horodate le départ et immobilise le véhicule")
        void demarrage() {
            enBase(penalite(TypeSanction.IMMOBILISATION, StatutLignePenalite.EN_ATTENTE, 0));

            demarrerUseCase.executer(PENALITE_ID);

            verify(lignePenaliteRepository).updateDebutImmobilisation(
                    org.mockito.ArgumentMatchers.eq(PENALITE_ID),
                    org.mockito.ArgumentMatchers.eq(StatutLignePenalite.EN_COURS),
                    any());
            verify(statutEventPublisher).publishStatutDirty(VEHICULE_ID);
        }

        @Test
        @DisplayName("On ne démarre pas l'immobilisation d'un simple buzzer")
        void demarrage_mauvaise_sanction() {
            enBase(penalite(TypeSanction.BUZZER, StatutLignePenalite.EN_ATTENTE, 0));

            assertThatThrownBy(() -> demarrerUseCase.executer(PENALITE_ID))
                    .isInstanceOf(LignePenaliteNonDemarrableException.class);
            verifyNoInteractions(statutEventPublisher);
        }

        @Test
        @DisplayName("Une immobilisation déjà en cours ne se redémarre pas")
        void demarrage_deja_en_cours() {
            enBase(penalite(TypeSanction.IMMOBILISATION, StatutLignePenalite.EN_COURS, 0));

            assertThatThrownBy(() -> demarrerUseCase.executer(PENALITE_ID))
                    .isInstanceOf(LignePenaliteNonDemarrableException.class);
        }

        @Test
        @DisplayName("Lever l'immobilisation horodate la fin et rend le véhicule au parc")
        void levee() {
            enBase(penalite(TypeSanction.IMMOBILISATION, StatutLignePenalite.EN_COURS, 0));

            leverUseCase.executer(PENALITE_ID);

            verify(lignePenaliteRepository).updateFinImmobilisation(
                    org.mockito.ArgumentMatchers.eq(PENALITE_ID),
                    org.mockito.ArgumentMatchers.eq(StatutLignePenalite.LEVEE),
                    any());
            verify(statutEventPublisher).publishStatutDirty(VEHICULE_ID);
        }

        @Test
        @DisplayName("On ne lève pas une immobilisation jamais démarrée")
        void levee_sans_demarrage() {
            enBase(penalite(TypeSanction.IMMOBILISATION, StatutLignePenalite.EN_ATTENTE, 0));

            assertThatThrownBy(() -> leverUseCase.executer(PENALITE_ID))
                    .isInstanceOf(LignePenaliteNonLevableException.class);
            verifyNoInteractions(statutEventPublisher);
        }

        @Test
        @DisplayName("Une immobilisation déjà levée ne se relève pas")
        void levee_deja_levee() {
            enBase(penalite(TypeSanction.IMMOBILISATION, StatutLignePenalite.LEVEE, 0));

            assertThatThrownBy(() -> leverUseCase.executer(PENALITE_ID))
                    .isInstanceOf(LignePenaliteNonLevableException.class);
        }
    }

    @Nested
    @DisplayName("Annulation")
    class Annulation {

        @Test
        @DisplayName("Une pénalité en attente s'annule avec son motif")
        void annulation_nominale() {
            enBase(penalite(TypeSanction.AMENDE, StatutLignePenalite.EN_ATTENTE, 0));

            annulerUseCase.executer(PENALITE_ID, "  faute contestée  ");

            verify(lignePenaliteRepository).updateStatutEtMotifAnnulation(
                    PENALITE_ID, StatutLignePenalite.ANNULEE, "faute contestée");
        }

        @Test
        @DisplayName("Annuler une pénalité déjà annulée ne change rien")
        void annulation_idempotente() {
            enBase(penalite(TypeSanction.AMENDE, StatutLignePenalite.ANNULEE, 0));

            annulerUseCase.executer(PENALITE_ID, "autre motif");

            verify(lignePenaliteRepository, never()).updateStatutEtMotifAnnulation(anyLong(), any(), any());
        }

        @ParameterizedTest(name = "statut {0} → annulation refusée")
        @EnumSource(value = StatutLignePenalite.class,
                names = {"ENCAISSEE", "EXECUTEE", "NOTIFIEE", "LEVEE"})
        @DisplayName("Une sanction déjà exécutée ne s'annule plus")
        void statut_terminal(StatutLignePenalite statut) {
            enBase(penalite(TypeSanction.AMENDE, statut, 0));

            assertThatThrownBy(() -> annulerUseCase.executer(PENALITE_ID, "motif"))
                    .isInstanceOf(LignePenaliteDejaTermineeException.class);
        }

        @Test
        @DisplayName("Un motif vide est refusé")
        void motif_obligatoire() {
            enBase(penalite(TypeSanction.AMENDE, StatutLignePenalite.EN_ATTENTE, 0));

            assertThatThrownBy(() -> annulerUseCase.executer(PENALITE_ID, "  "))
                    .isInstanceOf(IllegalArgumentException.class);
        }

        @Test
        @DisplayName("Une amende déjà payée ne s'annule pas directement")
        void avec_versement() {
            enBase(penalite(TypeSanction.AMENDE, StatutLignePenalite.PARTIELLEMENT_ENCAISSEE, 2_000));

            assertThatThrownBy(() -> annulerUseCase.executer(PENALITE_ID, "motif"))
                    .isInstanceOf(IllegalStateException.class)
                    .hasMessageContaining("Annulez d'abord les encaissements");
        }
    }

    @Nested
    @DisplayName("Reste dû d'une amende")
    class Amende {

        @Test
        @DisplayName("Le reste dû décroît avec les versements")
        void reste_du() {
            assertThat(penalite(TypeSanction.AMENDE, StatutLignePenalite.PARTIELLEMENT_ENCAISSEE, 2_000)
                    .montantRestant()).isEqualByComparingTo("3000");
        }

        @Test
        @DisplayName("Un trop-perçu ne rend jamais un reste dû négatif")
        void jamais_negatif() {
            assertThat(penalite(TypeSanction.AMENDE, StatutLignePenalite.ENCAISSEE, 6_000)
                    .montantRestant()).isEqualByComparingTo("0");
        }

        @Test
        @DisplayName("Une sanction sans montant a un reste dû nul")
        void sanction_sans_montant() {
            LignePenalite buzzer = penalite(TypeSanction.BUZZER, StatutLignePenalite.EN_ATTENTE, 0);
            buzzer.setMontant(null);

            assertThat(buzzer.montantRestant()).isEqualByComparingTo("0");
        }

        @Test
        @DisplayName("Le statut de l'amende se recalcule depuis ses encaissements")
        void recalcul_statut() {
            LignePenalite amende = penalite(TypeSanction.AMENDE, StatutLignePenalite.EN_ATTENTE, 0);
            amende.setEncaissements(new ArrayList<>(List.of(
                    EncaissementPenalite.builder().montant(BigDecimal.valueOf(2_000)).build(),
                    EncaissementPenalite.builder().montant(BigDecimal.valueOf(3_000)).build())));

            amende.recalculerStatutAmende();

            assertThat(amende.getMontantEncaisse()).isEqualByComparingTo("5000");
            assertThat(amende.getStatut()).isEqualTo(StatutLignePenalite.ENCAISSEE);
        }

        @Test
        @DisplayName("Un versement partiel laisse l'amende partiellement encaissée")
        void recalcul_partiel() {
            LignePenalite amende = penalite(TypeSanction.AMENDE, StatutLignePenalite.EN_ATTENTE, 0);
            amende.setEncaissements(new ArrayList<>(List.of(
                    EncaissementPenalite.builder().montant(BigDecimal.valueOf(2_000)).build())));

            amende.recalculerStatutAmende();

            assertThat(amende.getStatut()).isEqualTo(StatutLignePenalite.PARTIELLEMENT_ENCAISSEE);
        }
    }
}
