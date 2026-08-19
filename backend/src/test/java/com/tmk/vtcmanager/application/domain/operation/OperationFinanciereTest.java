package com.tmk.vtcmanager.application.domain.operation;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Ce qu'une écriture autorise encore, au seul vu de son état.
 *
 * <p>La contre-passation corrige une écriture ; elle ne corrige pas une
 * correction. Ce jugement appartient au domaine — les lectures le renvoient aux
 * clients pour qu'aucun n'ait à le refaire, et l'annulation l'oppose à qui
 * force le passage.
 */
class OperationFinanciereTest {

    private static OperationFinanciere.OperationFinanciereBuilder ecriture() {
        return OperationFinanciere.builder()
                .id(1L)
                .reference("DEP-2026-000042")
                .typeOperation(TypeOperation.DEPENSE)
                .montant(BigDecimal.valueOf(75_000))
                .dateOperation(LocalDate.of(2026, 8, 19))
                .statut(StatutOperation.PAYE);
    }

    @Test
    @DisplayName("Une écriture ordinaire se contre-passe")
    void ecriture_ordinaire() {
        assertThat(ecriture().build().estAnnulable()).isTrue();
    }

    @Test
    @DisplayName("Une extourne ne se contre-passe pas : elle est déjà la correction")
    void extourne() {
        assertThat(ecriture().extourneDeId(7L).build().estAnnulable()).isFalse();
    }

    @Test
    @DisplayName("Une écriture extournée non plus : son statut reste PAYE, pas son sort")
    void ecriture_extournee() {
        // Piège : l'annulation ne passe pas l'origine en ANNULEE — elle pose
        // annuleLe. Un client qui ne regarderait que le statut la croirait vive.
        OperationFinanciere extournee = ecriture()
                .annuleLe(LocalDateTime.of(2026, 8, 19, 10, 30))
                .motifAnnulation("montant erroné")
                .build();

        assertThat(extournee.getStatut()).isEqualTo(StatutOperation.PAYE);
        assertThat(extournee.estAnnulable()).isFalse();
    }

    @Test
    @DisplayName("Une écriture neutralisée ailleurs non plus")
    void ecriture_annulee() {
        assertThat(ecriture().statut(StatutOperation.ANNULEE).build().estAnnulable()).isFalse();
    }
}
