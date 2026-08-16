package com.tmk.vtcmanager.application.usecases.conditionTravail;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.conditionTravail.ConditionTravail;
import com.tmk.vtcmanager.application.domain.conditionTravail.PenaliteTemplate;
import com.tmk.vtcmanager.application.domain.conditionTravail.TypePenalite;
import com.tmk.vtcmanager.application.domain.conditionTravail.TypeSanction;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeChauffeur;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeTravail;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.ports.event.ChauffeurStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.event.VehiculeStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.application.ports.persistence.ConditionTravailRepository;
import com.tmk.vtcmanager.application.ports.persistence.ProgrammeTravailRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import com.tmk.vtcmanager.application.services.ConfigurationRecetteSynchronizer;
import com.tmk.vtcmanager.application.services.IndisponibiliteNettoyageService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

/**
 * Modification d'une condition de travail. C'est un point de propagation : la
 * condition est la source unique des règles, et la changer réaligne la
 * configuration de recette et le programme de chaque véhicule rattaché.
 *
 * <p>Le cas sensible est la réduction du nombre de chauffeurs : le chauffeur en
 * trop doit être dé-affecté du véhicule, ses congés devenus sans objet nettoyés,
 * et les deux statuts (véhicule et chauffeur) recalculés. Sans cela, un
 * chauffeur fantôme continue de générer des recettes.</p>
 */
class UpdateConditionTravailUseCaseTest {

    private static final Long CONDITION_ID = 1L;
    private static final Long VEHICULE_ID = 5L;
    private static final Long CHAUFFEUR_A = 10L;
    private static final Long CHAUFFEUR_B = 20L;

    private ConditionTravailRepository conditionTravailRepository;
    private VehiculeRepository vehiculeRepository;
    private ProgrammeTravailRepository programmeTravailRepository;
    private ChauffeurRepository chauffeurRepository;
    private ConfigurationRecetteSynchronizer configurationRecetteSynchronizer;
    private IndisponibiliteNettoyageService indisponibiliteNettoyageService;
    private VehiculeStatutEventPublisher statutEventPublisher;
    private ChauffeurStatutEventPublisher chauffeurStatutEventPublisher;
    private UpdateConditionTravailUseCase useCase;

    @BeforeEach
    void setUp() {
        conditionTravailRepository = mock(ConditionTravailRepository.class);
        vehiculeRepository = mock(VehiculeRepository.class);
        programmeTravailRepository = mock(ProgrammeTravailRepository.class);
        chauffeurRepository = mock(ChauffeurRepository.class);
        configurationRecetteSynchronizer = mock(ConfigurationRecetteSynchronizer.class);
        indisponibiliteNettoyageService = mock(IndisponibiliteNettoyageService.class);
        statutEventPublisher = mock(VehiculeStatutEventPublisher.class);
        chauffeurStatutEventPublisher = mock(ChauffeurStatutEventPublisher.class);

        when(conditionTravailRepository.findById(CONDITION_ID))
                .thenReturn(Optional.of(new ConditionTravail()));
        when(conditionTravailRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(vehiculeRepository.findByConditionTravailId(CONDITION_ID)).thenReturn(List.of());
        when(programmeTravailRepository.findByVehiculeId(anyLong())).thenReturn(Optional.empty());
        when(programmeTravailRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(chauffeurRepository.findById(anyLong())).thenAnswer(inv ->
                Optional.of(Chauffeur.builder().id(inv.getArgument(0)).build()));
        when(chauffeurRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        useCase = new UpdateConditionTravailUseCase(conditionTravailRepository, vehiculeRepository,
                programmeTravailRepository, chauffeurRepository, configurationRecetteSynchronizer,
                indisponibiliteNettoyageService, statutEventPublisher, chauffeurStatutEventPublisher);
    }

    /** Condition minimale valide : un chauffeur, recette réelle, versement journalier. */
    private ConditionTravail condition() {
        ConditionTravail condition = new ConditionTravail();
        condition.setNom("Journalier");
        condition.setNbChauffeurs(1);
        condition.setTypeRecette("MONTANT_REEL");
        condition.setFrequenceVersement("JOURNALIER");
        return condition;
    }

    private ConditionTravail conditionDeuxChauffeurs(String modeAlternance) {
        ConditionTravail condition = condition();
        condition.setNbChauffeurs(2);
        condition.setModeAlternance(modeAlternance);
        if ("AUTOMATIQUE".equals(modeAlternance)) {
            condition.setJoursAlternance(1);
            condition.setDateDebutAlternance(LocalDate.of(2026, 4, 1));
        }
        return condition;
    }

    private PenaliteTemplate penalite(TypeSanction sanction) {
        PenaliteTemplate template = new PenaliteTemplate();
        template.setTypePenalite(TypePenalite.RECETTE_NON_VERSEE.name());
        template.setTypeSanction(sanction.name());
        template.setDureeSanctionSecondes(30);
        template.setDureeImmobilisationMinutes(60);
        template.setMontant(5_000d);
        return template;
    }

    private ProgrammeTravail programmeAvecDeuxChauffeurs() {
        ProgrammeTravail programme = ProgrammeTravail.builder()
                .id(1L).vehiculeId(VEHICULE_ID).nombreChauffeursAutorises(2)
                .chauffeurs(new ArrayList<>(List.of(
                        ProgrammeChauffeur.builder()
                                .chauffeur(Chauffeur.builder().id(CHAUFFEUR_A).build())
                                .ordreAlternance(1).build(),
                        ProgrammeChauffeur.builder()
                                .chauffeur(Chauffeur.builder().id(CHAUFFEUR_B).build())
                                .ordreAlternance(2).build())))
                .build();
        when(vehiculeRepository.findByConditionTravailId(CONDITION_ID))
                .thenReturn(List.of(Vehicule.builder().id(VEHICULE_ID).build()));
        when(programmeTravailRepository.findByVehiculeId(VEHICULE_ID))
                .thenReturn(Optional.of(programme));
        return programme;
    }

    @Nested
    @DisplayName("Validation")
    class Validation {

        @Test
        @DisplayName("Un nombre de chauffeurs hors 1-2 est refusé")
        void nombre_chauffeurs() {
            ConditionTravail condition = condition();
            condition.setNbChauffeurs(0);
            assertThatThrownBy(() -> useCase.execute(CONDITION_ID, condition))
                    .isInstanceOf(IllegalArgumentException.class);

            condition.setNbChauffeurs(3);
            assertThatThrownBy(() -> useCase.execute(CONDITION_ID, condition))
                    .isInstanceOf(IllegalArgumentException.class);
        }

        @Test
        @DisplayName("Deux chauffeurs exigent un mode d'alternance")
        void mode_alternance_obligatoire() {
            ConditionTravail condition = condition();
            condition.setNbChauffeurs(2);

            assertThatThrownBy(() -> useCase.execute(CONDITION_ID, condition))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessageContaining("mode d'alternance");
        }

        @Test
        @DisplayName("L'alternance automatique exige un rythme entre 1 et 3 jours")
        void jours_alternance() {
            ConditionTravail condition = conditionDeuxChauffeurs("AUTOMATIQUE");
            condition.setJoursAlternance(4);

            assertThatThrownBy(() -> useCase.execute(CONDITION_ID, condition))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessageContaining("entre 1 et 3");
        }

        @Test
        @DisplayName("L'alternance automatique exige une date de départ")
        void date_debut_alternance() {
            ConditionTravail condition = conditionDeuxChauffeurs("AUTOMATIQUE");
            condition.setDateDebutAlternance(null);

            assertThatThrownBy(() -> useCase.execute(CONDITION_ID, condition))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessageContaining("date de début");
        }

        @Test
        @DisplayName("Une recette fixe exige un montant de jour de salaire")
        void montant_jour_salaire_obligatoire() {
            ConditionTravail condition = condition();
            condition.setTypeRecette("MONTANT_FIXE");

            assertThatThrownBy(() -> useCase.execute(CONDITION_ID, condition))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessageContaining("jour de salaire");
        }

        @Test
        @DisplayName("Un versement hebdomadaire exige son jour")
        void jour_versement_obligatoire() {
            ConditionTravail condition = condition();
            condition.setFrequenceVersement("HEBDOMADAIRE");

            assertThatThrownBy(() -> useCase.execute(CONDITION_ID, condition))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessageContaining("jour de versement");
        }

        @Test
        @DisplayName("Un type de pénalité ou de sanction inconnu est refusé")
        void types_penalite_invalides() {
            ConditionTravail condition = condition();
            PenaliteTemplate inconnue = penalite(TypeSanction.AMENDE);
            inconnue.setTypePenalite("RETARD_INJUSTIFIE");
            condition.setPenalites(List.of(inconnue));

            assertThatThrownBy(() -> useCase.execute(CONDITION_ID, condition))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessageContaining("Type de pénalité invalide");

            PenaliteTemplate sanctionInconnue = penalite(TypeSanction.AMENDE);
            sanctionInconnue.setTypeSanction("MISE_A_PIED");
            condition.setPenalites(List.of(sanctionInconnue));

            assertThatThrownBy(() -> useCase.execute(CONDITION_ID, condition))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessageContaining("Type de sanction invalide");
        }

        @Test
        @DisplayName("Chaque sanction exige le paramètre qui la rend applicable")
        void parametres_de_sanction() {
            ConditionTravail condition = condition();

            PenaliteTemplate buzzerSansDuree = penalite(TypeSanction.BUZZER);
            buzzerSansDuree.setDureeSanctionSecondes(0);
            condition.setPenalites(List.of(buzzerSansDuree));
            assertThatThrownBy(() -> useCase.execute(CONDITION_ID, condition))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessageContaining("durée en secondes");

            PenaliteTemplate amendeSansMontant = penalite(TypeSanction.AMENDE);
            amendeSansMontant.setMontant(null);
            condition.setPenalites(List.of(amendeSansMontant));
            assertThatThrownBy(() -> useCase.execute(CONDITION_ID, condition))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessageContaining("montant");

            PenaliteTemplate immobilisationSansDuree = penalite(TypeSanction.IMMOBILISATION);
            immobilisationSansDuree.setDureeImmobilisationMinutes(null);
            condition.setPenalites(List.of(immobilisationSansDuree));
            assertThatThrownBy(() -> useCase.execute(CONDITION_ID, condition))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessageContaining("durée d'immobilisation");
        }

        @Test
        @DisplayName("Un avertissement n'exige aucun paramètre")
        void avertissement_sans_parametre() {
            ConditionTravail condition = condition();
            condition.setPenalites(List.of(penalite(TypeSanction.AVERTISSEMENT)));

            assertThatCode(() -> useCase.execute(CONDITION_ID, condition)).doesNotThrowAnyException();
        }

        @Test
        @DisplayName("Une condition inexistante est refusée")
        void condition_introuvable() {
            when(conditionTravailRepository.findById(CONDITION_ID)).thenReturn(Optional.empty());

            assertThatThrownBy(() -> useCase.execute(CONDITION_ID, condition()))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessageContaining("introuvable");
        }
    }

    @Nested
    @DisplayName("Nettoyage des champs sans objet")
    class Sanitize {

        @Test
        @DisplayName("Un seul chauffeur efface toute l'alternance")
        void un_chauffeur_efface_alternance() {
            ConditionTravail condition = condition();
            condition.setModeAlternance("AUTOMATIQUE");
            condition.setJoursAlternance(2);
            condition.setDateDebutAlternance(LocalDate.of(2026, 4, 1));

            ConditionTravail saved = useCase.execute(CONDITION_ID, condition);

            assertThat(saved.getModeAlternance()).isNull();
            assertThat(saved.getJoursAlternance()).isNull();
            assertThat(saved.getDateDebutAlternance()).isNull();
        }

        @Test
        @DisplayName("L'alternance manuelle n'a ni rythme ni date de départ")
        void manuelle_efface_rythme() {
            ConditionTravail condition = conditionDeuxChauffeurs("MANUELLE");
            condition.setJoursAlternance(2);
            condition.setDateDebutAlternance(LocalDate.of(2026, 4, 1));

            ConditionTravail saved = useCase.execute(CONDITION_ID, condition);

            assertThat(saved.getJoursAlternance()).isNull();
            assertThat(saved.getDateDebutAlternance()).isNull();
        }

        @Test
        @DisplayName("Une recette réelle efface les montants spéciaux")
        void recette_reelle_efface_montants() {
            ConditionTravail condition = condition();
            condition.setMontantJourSalaire(BigDecimal.valueOf(5_000));
            condition.setMontantJourFerie(BigDecimal.valueOf(8_000));

            ConditionTravail saved = useCase.execute(CONDITION_ID, condition);

            assertThat(saved.getMontantJourSalaire()).isNull();
            assertThat(saved.getMontantJourFerie()).isNull();
        }

        @Test
        @DisplayName("Sans prise en compte des fériés, le montant férié est effacé")
        void feries_inactifs_effacent_le_montant() {
            ConditionTravail condition = condition();
            condition.setTypeRecette("MONTANT_FIXE");
            condition.setMontantJourSalaire(BigDecimal.ZERO);
            condition.setMontantJourFerie(BigDecimal.valueOf(8_000));
            condition.setFeriesConsideres(false);

            assertThat(useCase.execute(CONDITION_ID, condition).getMontantJourFerie()).isNull();
        }

        @Test
        @DisplayName("Avec les fériés actifs, le montant férié est conservé")
        void feries_actifs_conservent_le_montant() {
            ConditionTravail condition = condition();
            condition.setTypeRecette("MONTANT_FIXE");
            condition.setMontantJourSalaire(BigDecimal.ZERO);
            condition.setMontantJourFerie(BigDecimal.valueOf(8_000));
            condition.setFeriesConsideres(true);

            assertThat(useCase.execute(CONDITION_ID, condition).getMontantJourFerie())
                    .isEqualByComparingTo("8000");
        }

        @Test
        @DisplayName("Un versement non hebdomadaire efface le jour de versement")
        void jour_versement_efface() {
            ConditionTravail condition = condition();
            condition.setJourVersement("VENDREDI");

            assertThat(useCase.execute(CONDITION_ID, condition).getJourVersement()).isNull();
        }
    }

    @Nested
    @DisplayName("Propagation aux véhicules")
    class Propagation {

        @Test
        @DisplayName("Chaque véhicule rattaché voit sa configuration de recette réalignée")
        void configuration_synchronisee() {
            when(vehiculeRepository.findByConditionTravailId(CONDITION_ID)).thenReturn(List.of(
                    Vehicule.builder().id(VEHICULE_ID).build(),
                    Vehicule.builder().id(6L).build()));

            ConditionTravail saved = useCase.execute(CONDITION_ID, condition());

            verify(configurationRecetteSynchronizer).synchroniser(VEHICULE_ID, saved);
            verify(configurationRecetteSynchronizer).synchroniser(6L, saved);
        }

        @Test
        @DisplayName("Le programme du véhicule est réaligné et ses congés inertes nettoyés")
        void programme_realigne() {
            ProgrammeTravail programme = programmeAvecDeuxChauffeurs();

            useCase.execute(CONDITION_ID, conditionDeuxChauffeurs("MANUELLE"));

            verify(programmeTravailRepository).save(programme);
            verify(indisponibiliteNettoyageService).nettoyerInertes(programme);
        }

        @Test
        @DisplayName("Sans véhicule rattaché, rien n'est propagé")
        void aucun_vehicule() {
            useCase.execute(CONDITION_ID, condition());

            verifyNoInteractions(configurationRecetteSynchronizer, indisponibiliteNettoyageService,
                    statutEventPublisher, chauffeurStatutEventPublisher);
        }

        @Test
        @DisplayName("Passer à un chauffeur retire le second et le dé-affecte du véhicule")
        void reduction_retire_le_second_chauffeur() {
            ProgrammeTravail programme = programmeAvecDeuxChauffeurs();

            useCase.execute(CONDITION_ID, condition());

            // Seul le premier de l'ordre d'alternance conserve le véhicule.
            assertThat(programme.getChauffeurs()).hasSize(1);
            assertThat(programme.getChauffeurs().get(0).getChauffeurId()).isEqualTo(CHAUFFEUR_A);
            verify(chauffeurRepository).findById(CHAUFFEUR_B);
            verify(chauffeurRepository).save(any(Chauffeur.class));
        }

        @Test
        @DisplayName("Le chauffeur retiré voit ses congés orphelins nettoyés et son statut recalculé")
        void reduction_nettoie_et_recalcule() {
            programmeAvecDeuxChauffeurs();

            useCase.execute(CONDITION_ID, condition());

            verify(indisponibiliteNettoyageService).nettoyerSiOrphelin(CHAUFFEUR_B);
            verify(chauffeurStatutEventPublisher).publishStatutDirty(CHAUFFEUR_B);
            // Le véhicule a perdu un conducteur : son statut peut changer.
            verify(statutEventPublisher).publishStatutDirty(VEHICULE_ID);
        }

        @Test
        @DisplayName("Sans réduction d'effectif, aucun statut n'est recalculé")
        void aucune_reduction() {
            programmeAvecDeuxChauffeurs();

            useCase.execute(CONDITION_ID, conditionDeuxChauffeurs("MANUELLE"));

            verify(statutEventPublisher, never()).publishStatutDirty(anyLong());
            verify(chauffeurStatutEventPublisher, never()).publishStatutDirty(anyLong());
            verify(indisponibiliteNettoyageService, never()).nettoyerSiOrphelin(anyLong());
        }
    }
}
