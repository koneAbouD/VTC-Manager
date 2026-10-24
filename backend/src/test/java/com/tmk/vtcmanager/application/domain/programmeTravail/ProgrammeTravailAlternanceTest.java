package com.tmk.vtcmanager.application.domain.programmeTravail;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Le conducteur facturé doit être celui que le calendrier du programme montre.
 *
 * <p>Le backend comptait des jours calendaires depuis la date de début, quand
 * le mobile repousse le départ à la prise de service du binôme et ne compte que
 * les jours partagés : la recette d'un jour tombait sur le chauffeur au repos
 * pendant que l'autre roulait.
 */
class ProgrammeTravailAlternanceTest {

    private static final long PREMIER = 1L;
    private static final long SECOND = 2L;
    /** Lundi. */
    private static final LocalDate DEBUT = LocalDate.of(2026, 10, 5);

    private ProgrammeTravail programme(LocalDate dateServicePremier, LocalDate dateServiceSecond) {
        return ProgrammeTravail.builder()
                .vehiculeId(10L)
                .nombreChauffeursAutorises(2)
                .modeAlternance(ModeAlternance.AUTOMATIQUE)
                .joursAlternance(1)
                .dateDebutAlternance(DEBUT)
                .joursAlternanceSemaine(EnumSet.allOf(JourSemaine.class))
                .chauffeurs(new ArrayList<>(List.of(
                        chauffeur(PREMIER, 1, dateServicePremier),
                        chauffeur(SECOND, 2, dateServiceSecond))))
                .build();
    }

    private static ProgrammeChauffeur chauffeur(long id, int ordre, LocalDate dateService) {
        return ProgrammeChauffeur.builder()
                .chauffeur(Chauffeur.builder().id(id).build())
                .ordreAlternance(ordre)
                .dateService(dateService)
                .build();
    }

    @Test
    @DisplayName("Sans prise de service décalée, un jour sur deux en partant du premier")
    void alternance_simple() {
        ProgrammeTravail p = programme(null, null);

        assertThat(p.chauffeursActifs(DEBUT)).containsExactly(PREMIER);
        assertThat(p.chauffeursActifs(DEBUT.plusDays(1))).containsExactly(SECOND);
        assertThat(p.chauffeursActifs(DEBUT.plusDays(2))).containsExactly(PREMIER);
    }

    @Test
    @DisplayName("L'alternance part de la prise de service la plus tardive du binôme")
    void depart_a_la_prise_de_service() {
        // Le second arrive le mardi : l'alternance démarre ce jour-là, au premier.
        ProgrammeTravail p = programme(null, DEBUT.plusDays(1));

        assertThat(p.chauffeursActifs(DEBUT)).containsExactly(PREMIER);
        assertThat(p.chauffeursActifs(DEBUT.plusDays(1))).containsExactly(PREMIER);
        assertThat(p.chauffeursActifs(DEBUT.plusDays(2))).containsExactly(SECOND);
    }

    @Test
    @DisplayName("Un chauffeur pas encore en service ne roule pas")
    void chauffeur_pas_encore_en_service() {
        ProgrammeTravail p = programme(null, DEBUT.plusDays(10));

        assertThat(p.chauffeursActifs(DEBUT.plusDays(3))).containsExactly(PREMIER);
    }

    @Test
    @DisplayName("Un jour hors semaine partagée ne fait pas tourner le tour")
    void jour_non_partage_ignore() {
        ProgrammeTravail p = programme(null, null);
        p.setJoursAlternanceSemaine(EnumSet.complementOf(EnumSet.of(JourSemaine.DIMANCHE)));
        LocalDate samedi = DEBUT.plusDays(5);
        LocalDate lundi = DEBUT.plusDays(7);

        // Lun→Sam : 6 jours comptés, le samedi revient au second.
        assertThat(p.chauffeursActifs(samedi)).containsExactly(SECOND);
        // Le dimanche ne compte pas : le lundi passe au premier.
        assertThat(p.chauffeursActifs(lundi)).containsExactly(PREMIER);
    }
}
