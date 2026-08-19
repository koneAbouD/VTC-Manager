package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.programmeTravail.JourSemaine;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeChauffeur;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeTravail;
import com.tmk.vtcmanager.application.ports.persistence.ProgrammeTravailRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * Qui prend le volant aujourd'hui.
 *
 * <p>Deux chauffeurs peuvent être « en service » sur le même véhicule sans
 * rouler le même jour : c'est le planning qui départage. La liste des chauffeurs
 * s'appuie dessus pour dire lequel est de service et lequel est au repos.
 */
class ChauffeursAuProgrammeServiceTest {

    /** Un lundi : le jour de la semaine compte, la date en elle-même non. */
    private static final LocalDate LUNDI = LocalDate.of(2026, 8, 17);

    private ProgrammeTravailRepository programmeRepository;
    private IndisponibiliteSubstitutionService substitutions;
    private ChauffeursAuProgrammeService service;

    @BeforeEach
    void setUp() {
        programmeRepository = mock(ProgrammeTravailRepository.class);
        substitutions = mock(IndisponibiliteSubstitutionService.class);
        when(substitutions.substitutionsForDate(any())).thenReturn(Map.of());
        service = new ChauffeursAuProgrammeService(programmeRepository, substitutions);
    }

    private static ProgrammeChauffeur affecte(long chauffeurId, int ordre) {
        return ProgrammeChauffeur.builder()
                .chauffeur(Chauffeur.builder().id(chauffeurId).build())
                .ordreAlternance(ordre)
                .build();
    }

    @Test
    @DisplayName("Un chauffeur seul sur son véhicule roule tous les jours ouverts")
    void chauffeur_unique() {
        when(programmeRepository.findAllWithChauffeurs()).thenReturn(List.of(
                ProgrammeTravail.builder()
                        .vehiculeId(1L)
                        .nombreChauffeursAutorises(1)
                        .chauffeurs(List.of(affecte(10L, 1)))
                        .build()));

        assertThat(service.chauffeurIds(LUNDI)).containsExactly(10L);
    }

    @Test
    @DisplayName("Le véhicule qui ne travaille pas ce jour-là ne met personne au volant")
    void jour_hors_programme() {
        when(programmeRepository.findAllWithChauffeurs()).thenReturn(List.of(
                ProgrammeTravail.builder()
                        .vehiculeId(1L)
                        .nombreChauffeursAutorises(1)
                        .joursTravailSemaine(Set.of(JourSemaine.SAMEDI, JourSemaine.DIMANCHE))
                        .chauffeurs(List.of(affecte(10L, 1)))
                        .build()));

        assertThat(service.chauffeurIds(LUNDI)).isEmpty();
    }

    @Test
    @DisplayName("Le titulaire indisponible cède sa place au remplaçant")
    void substitution() {
        when(programmeRepository.findAllWithChauffeurs()).thenReturn(List.of(
                ProgrammeTravail.builder()
                        .vehiculeId(1L)
                        .nombreChauffeursAutorises(1)
                        .chauffeurs(List.of(affecte(10L, 1)))
                        .build()));
        when(substitutions.substitutionsForDate(LUNDI)).thenReturn(Map.of(10L, 99L));

        assertThat(service.chauffeurIds(LUNDI)).containsExactly(99L);
    }
}
