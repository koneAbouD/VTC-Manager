package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.conditionTravail.ConditionTravail;
import com.tmk.vtcmanager.application.domain.conditionTravail.CotisationTemplate;
import com.tmk.vtcmanager.application.domain.configurationRecette.ConfigurationRecette;
import com.tmk.vtcmanager.application.domain.configurationRecette.CotisationRecette;
import com.tmk.vtcmanager.application.domain.configurationRecette.FrequenceVersement;
import com.tmk.vtcmanager.application.domain.configurationRecette.ModeEncaissement;
import com.tmk.vtcmanager.application.domain.configurationRecette.TypeRecetteConfiguration;
import com.tmk.vtcmanager.application.ports.persistence.ConfigurationRecetteRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * Projection d'une condition de travail (saisie par l'exploitant, en chaînes de
 * caractères) vers la configuration de recette lue à l'encaissement. Toute
 * valeur inconnue doit retomber sur un défaut permissif : une condition mal
 * saisie ne doit jamais bloquer un chauffeur au moment de verser.
 */
class ConfigurationRecetteSynchronizerTest {

    private static final Long VEHICULE_ID = 7L;

    private ConfigurationRecetteRepository configurationRecetteRepository;
    private ConfigurationRecetteSynchronizer synchronizer;

    @BeforeEach
    void setUp() {
        configurationRecetteRepository = mock(ConfigurationRecetteRepository.class);
        when(configurationRecetteRepository.findByVehiculeId(VEHICULE_ID)).thenReturn(Optional.empty());
        when(configurationRecetteRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        synchronizer = new ConfigurationRecetteSynchronizer(configurationRecetteRepository);
    }

    private ConditionTravail condition() {
        ConditionTravail condition = new ConditionTravail();
        condition.setNom("Journalier 15 000");
        condition.setTypeRecette("MONTANT_FIXE");
        condition.setObjectifRecette(BigDecimal.valueOf(15_000));
        condition.setModeEncaissement("ESPECES");
        condition.setFrequenceVersement("JOURNALIER");
        condition.setHeureVersement("19:30");
        condition.setMontantJourSalaire(BigDecimal.ZERO);
        condition.setMontantJourFerie(BigDecimal.valueOf(8_000));
        return condition;
    }

    private ConfigurationRecette synchroniser(ConditionTravail condition) {
        synchronizer.synchroniser(VEHICULE_ID, condition);
        ArgumentCaptor<ConfigurationRecette> capture =
                ArgumentCaptor.forClass(ConfigurationRecette.class);
        org.mockito.Mockito.verify(configurationRecetteRepository).save(capture.capture());
        return capture.getValue();
    }

    @Test
    @DisplayName("Les règles de la condition sont projetées sur la configuration du véhicule")
    void projection_complete() {
        ConfigurationRecette config = synchroniser(condition());

        assertThat(config.getVehiculeId()).isEqualTo(VEHICULE_ID);
        assertThat(config.getTypeRecette()).isEqualTo(TypeRecetteConfiguration.MONTANT_FIXE);
        assertThat(config.getModeEncaissement()).isEqualTo(ModeEncaissement.ESPECES);
        assertThat(config.getFrequenceVersement()).isEqualTo(FrequenceVersement.JOURNALIER);
        assertThat(config.getHeureLimiteVersement()).isEqualTo(LocalTime.of(19, 30));
        assertThat(config.getMontantObjectifParChauffeur()).isEqualByComparingTo("15000");
        assertThat(config.getMontantJourSalaire()).isEqualByComparingTo("0");
        assertThat(config.getMontantJourFerie()).isEqualByComparingTo("8000");
    }

    @Test
    @DisplayName("Une configuration existante est mise à jour, pas dupliquée")
    void configuration_existante_reutilisee() {
        ConfigurationRecette existante = ConfigurationRecette.builder()
                .id(42L).vehiculeId(VEHICULE_ID)
                .montantObjectifParChauffeur(BigDecimal.valueOf(10_000))
                .cotisations(new ArrayList<>())
                .build();
        when(configurationRecetteRepository.findByVehiculeId(VEHICULE_ID))
                .thenReturn(Optional.of(existante));

        ConfigurationRecette config = synchroniser(condition());

        assertThat(config.getId()).isEqualTo(42L);
        assertThat(config.getMontantObjectifParChauffeur()).isEqualByComparingTo("15000");
    }

    @Test
    @DisplayName("Les cotisations sont recopiées et numérotées dans l'ordre de saisie")
    void cotisations_ordonnees() {
        ConditionTravail condition = condition();
        condition.setCotisations(List.of(
                cotisation("Épargne", 1_000), cotisation("Assurance", 500), cotisation("Lavage", 300)));

        ConfigurationRecette config = synchroniser(condition);

        assertThat(config.getCotisations()).extracting(CotisationRecette::getNom)
                .containsExactly("Épargne", "Assurance", "Lavage");
        assertThat(config.getCotisations()).extracting(CotisationRecette::getOrdre)
                .containsExactly(1, 2, 3);
        assertThat(config.getCotisations().get(0).getMontant()).isEqualByComparingTo("1000");
    }

    @Test
    @DisplayName("Retirer les cotisations de la condition les retire de la configuration")
    void cotisations_remplacees() {
        ConfigurationRecette existante = ConfigurationRecette.builder()
                .id(42L).vehiculeId(VEHICULE_ID)
                .cotisations(new ArrayList<>(List.of(
                        CotisationRecette.builder().nom("Ancienne").montant(BigDecimal.TEN).ordre(1).build())))
                .build();
        when(configurationRecetteRepository.findByVehiculeId(VEHICULE_ID))
                .thenReturn(Optional.of(existante));

        ConditionTravail condition = condition();
        condition.setCotisations(null);

        assertThat(synchroniser(condition).getCotisations()).isEmpty();
    }

    @Test
    @DisplayName("Un type de recette inconnu vaut MONTANT_REEL")
    void type_recette_par_defaut() {
        ConditionTravail condition = condition();
        condition.setTypeRecette("AUTRE_CHOSE");

        assertThat(synchroniser(condition).getTypeRecette())
                .isEqualTo(TypeRecetteConfiguration.MONTANT_REEL);
    }

    @Test
    @DisplayName("Le mode d'encaissement tolère la casse et le singulier ESPECE")
    void mode_encaissement_tolerant() {
        ConditionTravail condition = condition();

        condition.setModeEncaissement("especes");
        assertThat(synchroniser(condition).getModeEncaissement()).isEqualTo(ModeEncaissement.ESPECES);
    }

    @Test
    @DisplayName("Un mode d'encaissement absent ou inconnu autorise les deux canaux")
    void mode_encaissement_par_defaut() {
        ConditionTravail condition = condition();
        condition.setModeEncaissement(null);

        assertThat(synchroniser(condition).getModeEncaissement()).isEqualTo(ModeEncaissement.LES_DEUX);
    }

    @Test
    @DisplayName("Une fréquence de versement inconnue vaut JOURNALIER")
    void frequence_par_defaut() {
        ConditionTravail condition = condition();
        condition.setFrequenceVersement("TRIMESTRIEL");

        assertThat(synchroniser(condition).getFrequenceVersement())
                .isEqualTo(FrequenceVersement.JOURNALIER);
    }

    @Test
    @DisplayName("Une heure de versement absente ou illisible vaut 18h00")
    void heure_par_defaut() {
        ConditionTravail condition = condition();
        condition.setHeureVersement("dix-neuf heures");

        assertThat(synchroniser(condition).getHeureLimiteVersement()).isEqualTo(LocalTime.of(18, 0));
    }

    private CotisationTemplate cotisation(String nom, int montant) {
        CotisationTemplate template = new CotisationTemplate();
        template.setNom(nom);
        template.setMontant(BigDecimal.valueOf(montant));
        return template;
    }
}
