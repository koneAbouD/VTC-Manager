package com.tmk.vtcmanager.application.usecases.recette;

import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.recette.ResultatGenerationJournee;
import com.tmk.vtcmanager.application.usecases.cotisation.GenererLignesCotisationUseCase;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Génération recettes + cotisations d'un seul geste.
 *
 * <p>Les règles métier (jour de salaire, alternance, immobilisation, purge,
 * anti-doublon) restent couvertes par les tests des deux use cases composés ;
 * ces tests fixent la composition : les deux tournent pour la même date, et
 * l'échec de l'un n'emporte pas l'autre.
 */
@DisplayName("Génération recettes et cotisations en un geste")
class GenererRecettesEtCotisationsUseCaseTest {

    private static final LocalDate HIER = LocalDate.of(2026, 10, 24);

    private GenererLignesRecetteUseCase recettes;
    private GenererLignesCotisationUseCase cotisations;
    private GenererRecettesEtCotisationsUseCase useCase;

    @BeforeEach
    void setUp() {
        recettes = mock(GenererLignesRecetteUseCase.class);
        cotisations = mock(GenererLignesCotisationUseCase.class);
        useCase = new GenererRecettesEtCotisationsUseCase(recettes, cotisations);
    }

    @Test
    @DisplayName("génère les deux pour la même date et compte les lignes de chaque côté")
    void genereLesDeux() {
        when(recettes.executer(HIER)).thenReturn(List.of(new LigneRecette(), new LigneRecette()));
        when(cotisations.executer(HIER)).thenReturn(
                List.of(new LigneCotisation(), new LigneCotisation(), new LigneCotisation()));

        ResultatGenerationJournee resultat = useCase.executer(HIER);

        verify(recettes).executer(HIER);
        verify(cotisations).executer(HIER);
        assertThat(resultat.date()).isEqualTo(HIER);
        assertThat(resultat.recettes()).isEqualTo(2);
        assertThat(resultat.cotisations()).isEqualTo(3);
        assertThat(resultat.recettesReussies()).isTrue();
        assertThat(resultat.cotisationsReussies()).isTrue();
    }

    @Test
    @DisplayName("un échec des recettes n'empêche pas les cotisations")
    void echecRecettesNEmportePasCotisations() {
        when(recettes.executer(HIER)).thenThrow(new IllegalStateException("Période clôturée"));
        when(cotisations.executer(HIER)).thenReturn(List.of(new LigneCotisation()));

        ResultatGenerationJournee resultat = useCase.executer(HIER);

        assertThat(resultat.recettesReussies()).isFalse();
        assertThat(resultat.erreurRecettes()).isEqualTo("Période clôturée");
        assertThat(resultat.recettes()).isZero();
        assertThat(resultat.cotisations()).isEqualTo(1);
        assertThat(resultat.cotisationsReussies()).isTrue();
    }

    @Test
    @DisplayName("un échec des cotisations laisse les recettes générées, avec un motif par défaut si l'exception est muette")
    void echecCotisationsGardeRecettes() {
        when(recettes.executer(HIER)).thenReturn(List.of(new LigneRecette()));
        when(cotisations.executer(HIER)).thenThrow(new RuntimeException());

        ResultatGenerationJournee resultat = useCase.executer(HIER);

        assertThat(resultat.recettes()).isEqualTo(1);
        assertThat(resultat.recettesReussies()).isTrue();
        assertThat(resultat.cotisationsReussies()).isFalse();
        assertThat(resultat.erreurCotisations()).isEqualTo("Génération des cotisations impossible.");
    }

    @Test
    @DisplayName("rien à générer (jour de salaire, véhicules immobilisés…) : zéro de chaque côté, sans erreur")
    void rienAGenerer() {
        when(recettes.executer(HIER)).thenReturn(List.of());
        when(cotisations.executer(HIER)).thenReturn(List.of());

        ResultatGenerationJournee resultat = useCase.executer(HIER);

        assertThat(resultat.recettes()).isZero();
        assertThat(resultat.cotisations()).isZero();
        assertThat(resultat.recettesReussies()).isTrue();
        assertThat(resultat.cotisationsReussies()).isTrue();
    }
}
