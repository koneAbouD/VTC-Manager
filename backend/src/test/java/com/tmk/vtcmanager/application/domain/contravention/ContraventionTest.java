package com.tmk.vtcmanager.application.domain.contravention;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThat;

class ContraventionTest {

    private Contravention reversee(int paye) {
        return Contravention.builder()
                .id(1L)
                .montant(BigDecimal.valueOf(10_000))
                .montantPaye(BigDecimal.valueOf(paye))
                .statut(ContraventionStatus.REVERSE)
                .build();
    }

    @Test
    @DisplayName("Le remboursement d'une contravention reversée la laisse reversée")
    void paiement_sur_reversee_garde_le_statut() {
        Contravention c = reversee(0);

        c.enregistrerPaiement(BigDecimal.valueOf(10_000));

        // PAYE la ferait compter de nouveau dans ce qui reste à reverser à l'État.
        assertThat(c.getStatut()).isEqualTo(ContraventionStatus.REVERSE);
        assertThat(c.getMontantPaye()).isEqualByComparingTo("10000");
        assertThat(c.getDatePaiement()).isNotNull();
    }

    @Test
    @DisplayName("Un remboursement partiel d'une contravention reversée ne la date pas payée")
    void paiement_partiel_sur_reversee() {
        Contravention c = reversee(0);

        c.enregistrerPaiement(BigDecimal.valueOf(4_000));

        assertThat(c.getStatut()).isEqualTo(ContraventionStatus.REVERSE);
        assertThat(c.getMontantPaye()).isEqualByComparingTo("4000");
        assertThat(c.getDatePaiement()).isNull();
    }

    @Test
    @DisplayName("Extourner le remboursement d'une reversée rouvre l'avance, statut inchangé")
    void annulation_paiement_sur_reversee() {
        Contravention c = reversee(0);
        c.enregistrerPaiement(BigDecimal.valueOf(10_000));

        c.annulerPaiement(BigDecimal.valueOf(10_000));

        assertThat(c.getStatut()).isEqualTo(ContraventionStatus.REVERSE);
        assertThat(c.getMontantPaye()).isEqualByComparingTo("0");
        assertThat(c.getDatePaiement()).isNull();
    }

    @Test
    @DisplayName("Hors reversement, le solde d'une contravention la passe PAYE")
    void paiement_complet_classique() {
        Contravention c = Contravention.builder()
                .montant(BigDecimal.valueOf(10_000))
                .montantPaye(BigDecimal.ZERO)
                .statut(ContraventionStatus.EN_ATTENTE)
                .build();

        c.enregistrerPaiement(BigDecimal.valueOf(10_000));

        assertThat(c.getStatut()).isEqualTo(ContraventionStatus.PAYE);
    }
}
