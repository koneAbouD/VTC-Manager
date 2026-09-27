package com.tmk.vtcmanager.application.usecases.cotisation;

import com.tmk.vtcmanager.application.domain.cotisation.ResultatAnnulationLot;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Annulation de masse des cotisations restées ouvertes d'une période : le refus
 * d'une ligne n'emporte pas les autres, et chacune passe par le cas unitaire.
 */
@DisplayName("Annulation de cotisations en lot")
class AnnulerLignesCotisationLotUseCaseTest {

    private AnnulerLigneCotisationUseCase unitaire;
    private AnnulerLignesCotisationLotUseCase useCase;

    @BeforeEach
    void setUp() {
        unitaire = mock(AnnulerLigneCotisationUseCase.class);
        useCase = new AnnulerLignesCotisationLotUseCase(unitaire);
    }

    @Test
    @DisplayName("une ligne refusée n'empêche pas l'annulation des autres")
    void verdictParLigne() {
        when(unitaire.executer(2L, "arrêté")).thenThrow(new IllegalStateException("fonds détenu"));

        List<ResultatAnnulationLot> resultats = useCase.executer(List.of(1L, 2L, 3L), "arrêté");

        assertThat(resultats).extracting(ResultatAnnulationLot::succes)
                .containsExactly(true, false, true);
        assertThat(resultats.get(1).message()).isEqualTo("fonds détenu");
    }

    @Test
    @DisplayName("un identifiant répété n'est traité qu'une fois")
    void dedoublonne() {
        useCase.executer(List.of(1L, 1L), "arrêté");

        verify(unitaire, times(1)).executer(1L, "arrêté");
    }

    @Test
    @DisplayName("sans motif, rien n'est annulé")
    void motifObligatoire() {
        assertThatThrownBy(() -> useCase.executer(List.of(1L), " "))
                .isInstanceOf(IllegalArgumentException.class);
        verify(unitaire, never()).executer(any(), anyString());
    }
}
