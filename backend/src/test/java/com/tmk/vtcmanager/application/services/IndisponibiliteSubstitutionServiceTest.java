package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.indisponibilite.Indisponibilite;
import com.tmk.vtcmanager.application.domain.indisponibilite.IndisponibiliteStatut;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * Remplacement « overlay » : les assignations du programme ne sont jamais
 * modifiées, la substitution est calculée à la lecture, jour par jour. C'est ce
 * qui permet qu'un congé de trois jours n'efface pas le titulaire du programme.
 */
class IndisponibiliteSubstitutionServiceTest {

    private static final LocalDate LUNDI = LocalDate.of(2026, 4, 6);

    private IndisponibiliteRepository indisponibiliteRepository;
    private IndisponibiliteSubstitutionService service;

    @BeforeEach
    void setUp() {
        indisponibiliteRepository = mock(IndisponibiliteRepository.class);
        service = new IndisponibiliteSubstitutionService(indisponibiliteRepository);
    }

    private Indisponibilite indispo(Long titulaire, Long remplacant,
                                    LocalDate debut, LocalDate fin, IndisponibiliteStatut statut) {
        return Indisponibilite.builder()
                .id(1L)
                .chauffeur(titulaire == null ? null : Chauffeur.builder().id(titulaire).build())
                .chauffeurRemplacant(remplacant == null ? null : Chauffeur.builder().id(remplacant).build())
                .dateDebut(debut).dateFin(fin).statut(statut)
                .build();
    }

    private void indisponibilites(Indisponibilite... items) {
        when(indisponibiliteRepository.findAll()).thenReturn(List.of(items));
        for (Indisponibilite i : items) {
            if (i.getChauffeur() != null) {
                when(indisponibiliteRepository.findByChauffeurId(i.getChauffeur().getId()))
                        .thenReturn(List.of(i));
            }
        }
    }

    @Test
    @DisplayName("Le titulaire indisponible est remplacé par son remplaçant, à sa place dans la liste")
    void substitution_appliquee() {
        indisponibilites(indispo(1L, 9L, LUNDI, LUNDI.plusDays(3), IndisponibiliteStatut.EN_COURS));

        assertThat(service.appliquer(List.of(1L, 2L), LUNDI)).containsExactly(9L, 2L);
    }

    @Test
    @DisplayName("Hors de la période d'indisponibilité, le titulaire conduit")
    void hors_periode() {
        indisponibilites(indispo(1L, 9L, LUNDI, LUNDI.plusDays(3), IndisponibiliteStatut.EN_COURS));

        assertThat(service.appliquer(List.of(1L, 2L), LUNDI.minusDays(1))).containsExactly(1L, 2L);
        assertThat(service.appliquer(List.of(1L, 2L), LUNDI.plusDays(4))).containsExactly(1L, 2L);
    }

    @Test
    @DisplayName("Les bornes de la période sont incluses")
    void bornes_incluses() {
        indisponibilites(indispo(1L, 9L, LUNDI, LUNDI.plusDays(3), IndisponibiliteStatut.EN_COURS));

        assertThat(service.appliquer(List.of(1L), LUNDI)).containsExactly(9L);
        assertThat(service.appliquer(List.of(1L), LUNDI.plusDays(3))).containsExactly(9L);
    }

    @Test
    @DisplayName("Une indisponibilité sans date de fin reste ouverte indéfiniment")
    void periode_ouverte() {
        indisponibilites(indispo(1L, 9L, LUNDI, null, IndisponibiliteStatut.EN_COURS));

        assertThat(service.appliquer(List.of(1L), LUNDI.plusYears(1))).containsExactly(9L);
    }

    @Test
    @DisplayName("Une indisponibilité annulée n'a plus aucun effet")
    void indisponibilite_annulee() {
        indisponibilites(indispo(1L, 9L, LUNDI, LUNDI.plusDays(3), IndisponibiliteStatut.ANNULEE));

        assertThat(service.appliquer(List.of(1L), LUNDI)).containsExactly(1L);
        assertThat(service.estIndisponible(1L, LUNDI)).isFalse();
    }

    @Test
    @DisplayName("Sans remplaçant désigné, aucune substitution : le véhicule perd son conducteur")
    void sans_remplacant() {
        indisponibilites(indispo(1L, null, LUNDI, LUNDI.plusDays(3), IndisponibiliteStatut.EN_COURS));

        assertThat(service.substitutionsForDate(LUNDI)).isEmpty();
        assertThat(service.appliquer(List.of(1L), LUNDI)).containsExactly(1L);
        // Le titulaire est bien indisponible pour autant : c'est le signal EN_CONGE.
        assertThat(service.estIndisponible(1L, LUNDI)).isTrue();
    }

    @Test
    @DisplayName("Un remplaçant identique au titulaire est ignoré")
    void remplacant_egal_titulaire() {
        indisponibilites(indispo(1L, 1L, LUNDI, LUNDI.plusDays(3), IndisponibiliteStatut.EN_COURS));

        assertThat(service.substitutionsForDate(LUNDI)).isEmpty();
    }

    @Test
    @DisplayName("Le remplaçant déjà planifié ce jour n'apparaît pas deux fois")
    void pas_de_doublon() {
        indisponibilites(indispo(1L, 2L, LUNDI, LUNDI.plusDays(3), IndisponibiliteStatut.EN_COURS));

        // Chauffeur 2 conduisait déjà : il ne doit pas générer deux recettes.
        assertThat(service.appliquer(List.of(1L, 2L), LUNDI)).containsExactly(2L);
    }

    @Test
    @DisplayName("Sans aucune substitution du jour, la liste planifiée est rendue telle quelle")
    void aucune_substitution() {
        when(indisponibiliteRepository.findAll()).thenReturn(List.of());

        List<Long> planifies = List.of(1L, 2L);
        assertThat(service.appliquer(planifies, LUNDI)).isSameAs(planifies);
    }

    @Test
    @DisplayName("Une indisponibilité sans date de début est inerte")
    void sans_date_debut() {
        indisponibilites(indispo(1L, 9L, null, LUNDI.plusDays(3), IndisponibiliteStatut.EN_COURS));

        assertThat(service.appliquer(List.of(1L), LUNDI)).containsExactly(1L);
    }

    @Test
    @DisplayName("estIndisponible renvoie faux pour un chauffeur non renseigné")
    void chauffeur_nul() {
        assertThat(service.estIndisponible(null, LUNDI)).isFalse();
    }

    @Test
    @DisplayName("Plusieurs indisponibilités du même jour sont toutes appliquées")
    void substitutions_multiples() {
        Indisponibilite premiere = indispo(1L, 9L, LUNDI, LUNDI, IndisponibiliteStatut.EN_COURS);
        Indisponibilite seconde = indispo(2L, 8L, LUNDI, LUNDI, IndisponibiliteStatut.EN_COURS);
        when(indisponibiliteRepository.findAll()).thenReturn(List.of(premiere, seconde));

        assertThat(service.appliquer(List.of(1L, 2L), LUNDI)).containsExactly(9L, 8L);
    }
}
