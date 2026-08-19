package com.tmk.vtcmanager.application.usecases;

import com.tmk.vtcmanager.application.domain.conditionTravail.TypeSanction;
import com.tmk.vtcmanager.application.domain.contravention.Contravention;
import com.tmk.vtcmanager.application.domain.contravention.ContraventionStatus;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;
import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import com.tmk.vtcmanager.application.domain.penalite.LignePenalite;
import com.tmk.vtcmanager.application.domain.penalite.StatutLignePenalite;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.exception.EcritureFigeeException;
import com.tmk.vtcmanager.application.ports.event.VehiculeStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.ContraventionRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.MaintenanceRepository;
import com.tmk.vtcmanager.application.services.VerrouArreteService;
import com.tmk.vtcmanager.application.usecases.contravention.RestaurerContraventionUseCase;
import com.tmk.vtcmanager.application.usecases.cotisation.RestaurerLigneCotisationUseCase;
import com.tmk.vtcmanager.application.usecases.maintenance.RestaurerMaintenanceUseCase;
import com.tmk.vtcmanager.application.usecases.penalite.RestaurerLignePenaliteUseCase;
import com.tmk.vtcmanager.application.usecases.recette.RestaurerLigneRecetteUseCase;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Restauration d'une créance ou d'une intervention annulée à tort.
 *
 * <p>Annuler est courant, se tromper en annulant l'est aussi : une recette
 * rayée pour le mauvais chauffeur, une maintenance abandonnée trop vite. La
 * restauration rend l'élément à l'état où il était dû — le statut se déduit de
 * ce qui a réellement été versé, jamais d'une mémoire de l'ancien statut — et
 * efface le marquage d'annulation, sans quoi l'élément resterait absent des
 * états reconstitués alors qu'il est de nouveau exigible.
 *
 * <p>Deux arrêtés ferment la porte : la clôture de période, qui fige le mois,
 * et la clôture de caisse, qui arrête une journée. Passé l'un ou l'autre, l'y
 * remettre après coup ferait mentir un état publié ou un comptage signé.
 */
class RestaurationAnnulationsTest {

    private static final Long ID = 42L;
    private static final LocalDate JOUR = LocalDate.of(2026, 8, 10);

    private final VerrouArreteService verrouArreteService = mock(VerrouArreteService.class);

    /** Un arrêté — période close ou caisse comptée — couvre désormais ce jour. */
    private void arreteCouvre(LocalDate date) {
        doThrow(new EcritureFigeeException("arrêté")).when(verrouArreteService).verifier(date);
    }

    @Nested
    @DisplayName("Ligne de recette")
    class Recette {

        private final LigneRecetteRepository repository = mock(LigneRecetteRepository.class);
        private final RestaurerLigneRecetteUseCase useCase =
                new RestaurerLigneRecetteUseCase(repository, verrouArreteService);

        private LigneRecette annulee(String encaisse) {
            LigneRecette ligne = LigneRecette.builder()
                    .id(ID).vehiculeId(5L).chauffeurId(1L).dateRecette(JOUR)
                    .montantAttendu(BigDecimal.valueOf(15_000))
                    .montantEncaisse(new BigDecimal(encaisse))
                    .statut(StatutLigneRecette.ANNULEE)
                    .motifAnnulation("erreur de saisie")
                    .annuleLe(LocalDateTime.of(2026, 8, 12, 9, 0))
                    .build();
            when(repository.findById(ID)).thenReturn(Optional.of(ligne));
            when(repository.save(any())).thenAnswer(i -> i.getArgument(0));
            return ligne;
        }

        @Test
        @DisplayName("Sans versement, la ligne repasse en attente et perd son marquage")
        void sans_versement() {
            LigneRecette ligne = annulee("0");

            LigneRecette restauree = useCase.executer(ID);

            assertThat(restauree.getStatut()).isEqualTo(StatutLigneRecette.EN_ATTENTE);
            assertThat(restauree.getMotifAnnulation()).isNull();
            assertThat(restauree.getAnnuleLe()).isNull();
            assertThat(ligne).isSameAs(restauree);
        }

        @Test
        @DisplayName("Avec un versement partiel, elle repasse partiellement encaissée")
        void versement_partiel() {
            annulee("5000");

            assertThat(useCase.executer(ID).getStatut())
                    .isEqualTo(StatutLigneRecette.PARTIELLEMENT_ENCAISSE);
        }

        @Test
        @DisplayName("Période close ou caisse comptée : la restauration est refusée")
        void arrete_couvrant() {
            annulee("0");
            arreteCouvre(JOUR);

            assertThatThrownBy(() -> useCase.executer(ID))
                    .isInstanceOf(EcritureFigeeException.class);
            verify(repository, never()).save(any());
        }

        @Test
        @DisplayName("Une ligne qui n'est pas annulée n'a rien à restaurer")
        void ligne_active() {
            when(repository.findById(ID)).thenReturn(Optional.of(LigneRecette.builder()
                    .id(ID).dateRecette(JOUR).statut(StatutLigneRecette.EN_ATTENTE).build()));

            assertThatThrownBy(() -> useCase.executer(ID))
                    .isInstanceOf(IllegalStateException.class);
        }
    }

    @Nested
    @DisplayName("Ligne de cotisation")
    class Cotisation {

        private final LigneCotisationRepository repository = mock(LigneCotisationRepository.class);
        private final RestaurerLigneCotisationUseCase useCase =
                new RestaurerLigneCotisationUseCase(repository, verrouArreteService);

        private void annulee(String encaisse) {
            when(repository.findById(ID)).thenReturn(Optional.of(LigneCotisation.builder()
                    .id(ID).vehiculeId(5L).chauffeurId(1L).dateCotisation(JOUR)
                    .montantDu(BigDecimal.valueOf(2_000))
                    .montantEncaisse(new BigDecimal(encaisse))
                    .statut(StatutLigneCotisation.ANNULEE)
                    .motifAnnulation("erreur")
                    .annuleLe(LocalDateTime.of(2026, 8, 12, 9, 0))
                    .build()));
            when(repository.save(any())).thenAnswer(i -> i.getArgument(0));
        }

        @Test
        @DisplayName("Sans versement, la ligne repasse en attente et perd son marquage")
        void sans_versement() {
            annulee("0");

            LigneCotisation restauree = useCase.executer(ID);

            assertThat(restauree.getStatut()).isEqualTo(StatutLigneCotisation.EN_ATTENTE);
            assertThat(restauree.getMotifAnnulation()).isNull();
            assertThat(restauree.getAnnuleLe()).isNull();
        }

        @Test
        @DisplayName("Avec un versement partiel, elle repasse partiellement encaissée")
        void versement_partiel() {
            annulee("500");

            assertThat(useCase.executer(ID).getStatut())
                    .isEqualTo(StatutLigneCotisation.PARTIELLEMENT_ENCAISSE);
        }

        @Test
        @DisplayName("Période close ou caisse comptée : la restauration est refusée")
        void arrete_couvrant() {
            annulee("0");
            arreteCouvre(JOUR);

            assertThatThrownBy(() -> useCase.executer(ID))
                    .isInstanceOf(EcritureFigeeException.class);
            verify(repository, never()).save(any());
        }
    }

    @Nested
    @DisplayName("Pénalité")
    class Penalite {

        private final LignePenaliteRepository repository = mock(LignePenaliteRepository.class);
        private final RestaurerLignePenaliteUseCase useCase =
                new RestaurerLignePenaliteUseCase(repository, verrouArreteService);

        private void annulee(TypeSanction sanction, String encaisse) {
            when(repository.findById(ID)).thenReturn(Optional.of(LignePenalite.builder()
                    .id(ID).vehiculeId(5L).chauffeurId(1L)
                    .dateFaute(JOUR).dateGeneration(JOUR)
                    .typeSanction(sanction)
                    .montant(BigDecimal.valueOf(10_000))
                    .montantEncaisse(new BigDecimal(encaisse))
                    .statut(StatutLignePenalite.ANNULEE)
                    .motifAnnulation("erreur")
                    .annuleLe(LocalDateTime.of(2026, 8, 12, 9, 0))
                    .build()));
            when(repository.save(any())).thenAnswer(i -> i.getArgument(0));
        }

        @Test
        @DisplayName("Une amende sans versement repasse en attente")
        void amende_sans_versement() {
            annulee(TypeSanction.AMENDE, "0");

            LignePenalite restauree = useCase.executer(ID);

            assertThat(restauree.getStatut()).isEqualTo(StatutLignePenalite.EN_ATTENTE);
            assertThat(restauree.getMotifAnnulation()).isNull();
            assertThat(restauree.getAnnuleLe()).isNull();
        }

        @Test
        @DisplayName("Une amende partiellement versée retrouve ce statut")
        void amende_partielle() {
            annulee(TypeSanction.AMENDE, "4000");

            assertThat(useCase.executer(ID).getStatut())
                    .isEqualTo(StatutLignePenalite.PARTIELLEMENT_ENCAISSEE);
        }

        @Test
        @DisplayName("Une sanction non pécuniaire repart en attente d'exécution")
        void buzzer_en_attente() {
            // Le buzzer annulé n'a pas retenti : il reste à appliquer.
            annulee(TypeSanction.BUZZER, "0");

            assertThat(useCase.executer(ID).getStatut())
                    .isEqualTo(StatutLignePenalite.EN_ATTENTE);
        }

        @Test
        @DisplayName("Période close ou caisse comptée : la restauration est refusée")
        void arrete_couvrant() {
            annulee(TypeSanction.AMENDE, "0");
            arreteCouvre(JOUR);

            assertThatThrownBy(() -> useCase.executer(ID))
                    .isInstanceOf(EcritureFigeeException.class);
            verify(repository, never()).save(any());
        }
    }

    @Nested
    @DisplayName("Contravention")
    class ContraventionRestauree {

        private final ContraventionRepository repository = mock(ContraventionRepository.class);
        private final RestaurerContraventionUseCase useCase =
                new RestaurerContraventionUseCase(repository, verrouArreteService);

        private void annulee(String paye) {
            when(repository.findById(ID)).thenReturn(Optional.of(Contravention.builder()
                    .id(ID).dateInfraction(JOUR)
                    .montant(BigDecimal.valueOf(50_000))
                    .montantPaye(new BigDecimal(paye))
                    .statut(ContraventionStatus.ANNULE)
                    .motifAnnulation("erreur")
                    .annulePar("gerant")
                    .annuleLe(LocalDateTime.of(2026, 8, 12, 9, 0))
                    .build()));
            when(repository.save(any())).thenAnswer(i -> i.getArgument(0));
        }

        @Test
        @DisplayName("Sans versement, elle repasse en attente et perd son marquage")
        void sans_versement() {
            annulee("0");

            Contravention restauree = useCase.execute(ID);

            assertThat(restauree.getStatut()).isEqualTo(ContraventionStatus.EN_ATTENTE);
            assertThat(restauree.getMotifAnnulation()).isNull();
            assertThat(restauree.getAnnulePar()).isNull();
            assertThat(restauree.getAnnuleLe()).isNull();
        }

        @Test
        @DisplayName("Avec un versement partiel, elle repasse partiellement payée")
        void versement_partiel() {
            annulee("20000");

            assertThat(useCase.execute(ID).getStatut())
                    .isEqualTo(ContraventionStatus.PARTIELLEMENT_PAYE);
        }

        @Test
        @DisplayName("Période close ou caisse comptée : la restauration est refusée")
        void arrete_couvrant() {
            annulee("0");
            arreteCouvre(JOUR);

            assertThatThrownBy(() -> useCase.execute(ID))
                    .isInstanceOf(EcritureFigeeException.class);
            verify(repository, never()).save(any());
        }
    }

    @Nested
    @DisplayName("Maintenance")
    class MaintenanceRestauree {

        private final MaintenanceRepository repository = mock(MaintenanceRepository.class);
        private final VehiculeStatutEventPublisher statutEventPublisher =
                mock(VehiculeStatutEventPublisher.class);
        private final RestaurerMaintenanceUseCase useCase =
                new RestaurerMaintenanceUseCase(repository, statutEventPublisher, verrouArreteService);

        private void annulee() {
            when(repository.findById(ID)).thenReturn(Optional.of(Maintenance.builder()
                    .id(ID).type("VIDANGE").datePrevue(JOUR)
                    .statut(MaintenanceStatus.ANNULEE)
                    .motifAnnulation("garage indisponible")
                    .annulePar("exploitant")
                    .annuleLe(LocalDateTime.of(2026, 8, 12, 9, 0))
                    .vehicule(Vehicule.builder().id(7L).build())
                    .build()));
            when(repository.save(any())).thenAnswer(i -> i.getArgument(0));
        }

        @Test
        @DisplayName("Elle repasse en planifiée et perd son marquage d'annulation")
        void repasse_planifiee() {
            annulee();

            Maintenance restauree = useCase.execute(ID);

            assertThat(restauree.getStatut()).isEqualTo(MaintenanceStatus.PLANIFIEE);
            assertThat(restauree.getMotifAnnulation()).isNull();
            assertThat(restauree.getAnnulePar()).isNull();
            assertThat(restauree.getAnnuleLe()).isNull();
        }

        @Test
        @DisplayName("Le statut du véhicule est recalculé")
        void statut_vehicule_recalcule() {
            annulee();

            useCase.execute(ID);

            verify(statutEventPublisher).publishStatutDirty(7L);
        }

        @Test
        @DisplayName("Période close ou caisse comptée : la restauration est refusée")
        void arrete_couvrant() {
            annulee();
            arreteCouvre(JOUR);

            assertThatThrownBy(() -> useCase.execute(ID))
                    .isInstanceOf(EcritureFigeeException.class);
            verify(repository, never()).save(any());
        }

        @Test
        @DisplayName("Une maintenance qui n'est pas annulée n'a rien à restaurer")
        void maintenance_active() {
            when(repository.findById(ID)).thenReturn(Optional.of(Maintenance.builder()
                    .id(ID).datePrevue(JOUR).statut(MaintenanceStatus.PLANIFIEE).build()));

            assertThatThrownBy(() -> useCase.execute(ID))
                    .isInstanceOf(IllegalStateException.class);
        }
    }
}
