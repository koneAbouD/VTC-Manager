package com.tmk.vtcmanager.application.usecases.cotisation;

import com.tmk.vtcmanager.application.domain.encaissement.MontantParLigne;
import com.tmk.vtcmanager.application.domain.encaissement.ResultatEncaissementLot;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.cotisation.EncaissementCotisation;
import com.tmk.vtcmanager.application.exception.PeriodeClotureeException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Encaissement de masse d'un versement : plusieurs journées soldées en une
 * fois, avec un montant propre à chaque ligne.
 *
 * <p>Ce que le lot garantit, et que ces tests fixent : le mode, la date et le
 * commentaire sont communs, le montant ne l'est pas, et le refus d'une ligne
 * n'emporte pas les autres — c'est le point qui distingue ce lot d'une
 * transaction unique.
 */
@DisplayName("Encaissement de cotisations en lot")
class CreateEncaissementsCotisationLotUseCaseTest {

    private static final LocalDate LE_JOUR = LocalDate.of(2026, 9, 2);

    private CreateEncaissementCotisationUseCase unitaire;
    private CreateEncaissementsCotisationLotUseCase useCase;

    @BeforeEach
    void setUp() {
        unitaire = mock(CreateEncaissementCotisationUseCase.class);
        useCase = new CreateEncaissementsCotisationLotUseCase(unitaire);
    }

    private static MontantParLigne ligne(long id, String montant) {
        return new MontantParLigne(id, new BigDecimal(montant));
    }

    private void repondEncaissement(long ligneId, long encaissementId) {
        when(unitaire.executer(eq(ligneId), any(EncaissementCotisation.class)))
                .thenReturn(EncaissementCotisation.builder().id(encaissementId).build());
    }

    @Test
    @DisplayName("chaque ligne reçoit son montant, avec le mode et la date du lot")
    void encaisseChaqueLigneAvecSonMontant() {
        repondEncaissement(1L, 11L);
        repondEncaissement(2L, 22L);

        List<ResultatEncaissementLot> resultats = useCase.executer(
                List.of(ligne(1L, "15000"), ligne(2L, "8000")),
                ModePaiement.ESPECES, LE_JOUR, "REF-1", "Versement du jour");

        ArgumentCaptor<EncaissementCotisation> capture = ArgumentCaptor.forClass(EncaissementCotisation.class);
        verify(unitaire).executer(eq(1L), capture.capture());
        verify(unitaire).executer(eq(2L), capture.capture());

        assertThat(capture.getAllValues())
                .extracting(EncaissementCotisation::getMontant)
                .containsExactly(new BigDecimal("15000"), new BigDecimal("8000"));
        assertThat(capture.getAllValues())
                .allSatisfy(e -> {
                    assertThat(e.getModeEncaissement()).isEqualTo(ModePaiement.ESPECES);
                    assertThat(e.getDateEncaissement()).isEqualTo(LE_JOUR);
                    assertThat(e.getReference()).isEqualTo("REF-1");
                    assertThat(e.getCommentaire()).isEqualTo("Versement du jour");
                });

        assertThat(resultats).extracting(ResultatEncaissementLot::succes)
                .containsExactly(true, true);
        assertThat(resultats).extracting(ResultatEncaissementLot::encaissementId)
                .containsExactly(11L, 22L);
    }

    @Test
    @DisplayName("une ligne refusée n'emporte pas les autres, et son motif est rendu tel quel")
    void unRefusNEmportePasLeLot() {
        repondEncaissement(1L, 11L);
        when(unitaire.executer(eq(2L), any(EncaissementCotisation.class)))
                .thenThrow(new PeriodeClotureeException(LocalDate.of(2026, 8, 31)));
        repondEncaissement(3L, 33L);

        List<ResultatEncaissementLot> resultats = useCase.executer(
                List.of(ligne(1L, "15000"), ligne(2L, "15000"), ligne(3L, "5000")),
                ModePaiement.ESPECES, LE_JOUR, null, null);

        // Les lignes qui passent sont bel et bien encaissées : l'argent est reçu,
        // le rejeter obligerait le guichet à tout ressaisir.
        verify(unitaire).executer(eq(3L), any(EncaissementCotisation.class));

        assertThat(resultats).extracting(ResultatEncaissementLot::succes)
                .containsExactly(true, false, true);
        assertThat(resultats.get(1).message())
                .contains("période comptable est clôturée");
        assertThat(resultats.get(1).encaissementId()).isNull();
    }

    @Test
    @DisplayName("un refus sans message reste lisible à l'écran")
    void refusSansMessage() {
        when(unitaire.executer(eq(1L), any(EncaissementCotisation.class)))
                .thenThrow(new IllegalStateException());

        List<ResultatEncaissementLot> resultats = useCase.executer(
                List.of(ligne(1L, "15000")), ModePaiement.MOBILE_MONEY, LE_JOUR, null, null);

        assertThat(resultats).singleElement()
                .satisfies(r -> {
                    assertThat(r.succes()).isFalse();
                    assertThat(r.message()).isEqualTo("Encaissement refusé.");
                });
    }
}
