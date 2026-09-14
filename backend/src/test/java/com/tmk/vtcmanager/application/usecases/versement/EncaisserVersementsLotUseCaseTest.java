package com.tmk.vtcmanager.application.usecases.versement;

import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.versement.PartVersement;
import com.tmk.vtcmanager.application.domain.versement.ResultatVersementLot;
import com.tmk.vtcmanager.application.domain.versement.SaisieVersement;
import com.tmk.vtcmanager.application.domain.versement.VersementEnregistre;
import com.tmk.vtcmanager.application.exception.EcritureFigeeException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * Encaissement de masse par versements. Chaque versement est un tout ; le lot
 * n'en est pas un : un refus ne vaut que pour le versement visé.
 */
@DisplayName("Encaissement de versements en lot")
class EncaisserVersementsLotUseCaseTest {

    private static final LocalDate VERSE_LE = LocalDate.of(2026, 9, 11);
    private static final UUID VERSEMENT = UUID.fromString("0b6f8a2e-0e6a-4c4e-9d1d-6f0a3c1b2d44");

    private EncaisserVersementUseCase unitaire;
    private EncaisserVersementsLotUseCase useCase;

    @BeforeEach
    void setUp() {
        unitaire = mock(EncaisserVersementUseCase.class);
        useCase = new EncaisserVersementsLotUseCase(unitaire);
    }

    private static SaisieVersement versement(Long recette, Long cotisation) {
        return new SaisieVersement(
                new PartVersement(recette, new BigDecimal("15000")),
                cotisation == null ? null : new PartVersement(cotisation, new BigDecimal("2000")),
                ModePaiement.ESPECES, VERSE_LE, null, null);
    }

    @Test
    @DisplayName("chaque versement rend son verdict, et un refus n'emporte pas les autres")
    void verdictParVersement() {
        SaisieVersement accepte = versement(1L, 91L);
        SaisieVersement refuse = versement(2L, null);
        when(unitaire.executer(accepte)).thenReturn(new VersementEnregistre(VERSEMENT, 11L, 22L, List.of(501L, 502L)));
        when(unitaire.executer(refuse)).thenThrow(new EcritureFigeeException(
                "La caisse a été comptée le 10/09/2026 : cette journée est close."));

        List<ResultatVersementLot> resultats = useCase.executer(List.of(accepte, refuse));

        assertThat(resultats).hasSize(2);
        assertThat(resultats.get(0).succes()).isTrue();
        assertThat(resultats.get(0).ligneRecetteId()).isEqualTo(1L);
        assertThat(resultats.get(0).ligneCotisationId()).isEqualTo(91L);
        assertThat(resultats.get(0).versementId()).isEqualTo(VERSEMENT);
        assertThat(resultats.get(0).operationIds()).containsExactly(501L, 502L);

        assertThat(resultats.get(1).succes()).isFalse();
        assertThat(resultats.get(1).ligneRecetteId()).isEqualTo(2L);
        assertThat(resultats.get(1).ligneCotisationId()).isNull();
        assertThat(resultats.get(1).message()).contains("cette journée est close");
        assertThat(resultats.get(1).operationIds()).isEmpty();
    }

    @Test
    @DisplayName("un refus sans message reçoit un libellé lisible, jamais une trace technique")
    void refusSansMessage() {
        SaisieVersement saisie = versement(1L, 91L);
        when(unitaire.executer(saisie)).thenThrow(new IllegalStateException());

        List<ResultatVersementLot> resultats = useCase.executer(List.of(saisie));

        assertThat(resultats.get(0).message()).isEqualTo("Encaissement refusé.");
    }
}
