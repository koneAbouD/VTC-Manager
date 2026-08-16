package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.jourFerie.JourFerie;
import com.tmk.vtcmanager.application.domain.jourFerie.SourceJourFerie;
import com.tmk.vtcmanager.application.domain.jourFerie.TypeJourFerie;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

import java.time.LocalDate;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Fériés déterministes de Côte d'Ivoire. Le calcul de Pâques est vérifié sur
 * des années de référence connues : c'est de lui que dérivent trois fériés, et
 * une erreur d'un jour y décalerait silencieusement les recettes du véhicule
 * dont l'option « fériés considérés » est active.
 */
class JoursFeriesCalculatorTest {

    private final JoursFeriesCalculator calculator = new JoursFeriesCalculator();

    private LocalDate dateDe(List<JourFerie> feries, String libelle) {
        return feries.stream()
                .filter(f -> libelle.equals(f.getLibelle()))
                .map(JourFerie::getDate)
                .findFirst()
                .orElseThrow(() -> new AssertionError("Férié absent : " + libelle));
    }

    @Test
    @DisplayName("L'année compte 7 fériés fixes et 3 fêtes chrétiennes mobiles")
    void dix_feries_par_an() {
        List<JourFerie> feries = calculator.genererAnnee(2026);

        assertThat(feries).hasSize(10);
        assertThat(feries).filteredOn(f -> f.getType() == TypeJourFerie.FIXE).hasSize(7);
        assertThat(feries).filteredOn(f -> f.getType() == TypeJourFerie.CHRETIEN).hasSize(3);
    }

    @Test
    @DisplayName("Les fériés civils fixes tombent aux dates attendues")
    void feries_fixes() {
        List<JourFerie> feries = calculator.genererAnnee(2026);

        assertThat(dateDe(feries, "Jour de l'An")).isEqualTo(LocalDate.of(2026, 1, 1));
        assertThat(dateDe(feries, "Fête du Travail")).isEqualTo(LocalDate.of(2026, 5, 1));
        assertThat(dateDe(feries, "Fête Nationale")).isEqualTo(LocalDate.of(2026, 8, 7));
        assertThat(dateDe(feries, "Assomption")).isEqualTo(LocalDate.of(2026, 8, 15));
        assertThat(dateDe(feries, "Toussaint")).isEqualTo(LocalDate.of(2026, 11, 1));
        assertThat(dateDe(feries, "Journée Nationale de la Paix")).isEqualTo(LocalDate.of(2026, 11, 15));
        assertThat(dateDe(feries, "Noël")).isEqualTo(LocalDate.of(2026, 12, 25));
    }

    /**
     * Dimanches de Pâques grégoriens de référence. Le Lundi de Pâques tombant
     * le lendemain, c'est lui qu'on observe pour valider l'algorithme.
     */
    @ParameterizedTest(name = "Pâques {0} → lundi de Pâques le {1}")
    @CsvSource({
            "2024, 2024-04-01",  // Pâques 31/03
            "2025, 2025-04-21",  // Pâques 20/04
            "2026, 2026-04-06",  // Pâques 05/04
            "2027, 2027-03-29",  // Pâques 28/03 — Pâques la plus précoce de la décennie
            "2038, 2038-04-26"   // Pâques 25/04 — borne haute de l'algorithme
    })
    @DisplayName("Le lundi de Pâques suit le dimanche de Pâques calculé")
    void lundi_de_paques(int annee, LocalDate attendu) {
        assertThat(dateDe(calculator.genererAnnee(annee), "Lundi de Pâques")).isEqualTo(attendu);
    }

    @Test
    @DisplayName("Ascension et Pentecôte se déduisent de Pâques (+39 et +50 jours)")
    void fetes_mobiles_derivees() {
        List<JourFerie> feries = calculator.genererAnnee(2026);
        LocalDate lundiPaques = dateDe(feries, "Lundi de Pâques");
        LocalDate paques = lundiPaques.minusDays(1);

        assertThat(dateDe(feries, "Ascension")).isEqualTo(paques.plusDays(39));
        assertThat(dateDe(feries, "Lundi de Pentecôte")).isEqualTo(paques.plusDays(50));
        // Repères 2026 : Pâques le 05/04, Ascension le 14/05, Pentecôte le 25/05.
        assertThat(dateDe(feries, "Ascension")).isEqualTo(LocalDate.of(2026, 5, 14));
        assertThat(dateDe(feries, "Lundi de Pentecôte")).isEqualTo(LocalDate.of(2026, 5, 25));
    }

    @Test
    @DisplayName("Tous les fériés générés sont marqués AUTO et rattachés à leur année")
    void source_auto_et_annee() {
        List<JourFerie> feries = calculator.genererAnnee(2026);

        assertThat(feries).allSatisfy(f -> {
            assertThat(f.getSource()).isEqualTo(SourceJourFerie.AUTO);
            assertThat(f.getAnnee()).isEqualTo(2026);
            assertThat(f.getDate().getYear()).isEqualTo(2026);
        });
    }

    @Test
    @DisplayName("Aucune fête musulmane n'est calculée : elles restent à saisir à la main")
    void pas_de_fetes_musulmanes() {
        List<JourFerie> feries = calculator.genererAnnee(2026);

        assertThat(feries).noneMatch(f -> f.getType() == TypeJourFerie.MUSULMAN);
        assertThat(feries).extracting(JourFerie::getLibelle)
                .doesNotContain("Aïd el-Fitr", "Tabaski", "Maouloud");
    }
}
