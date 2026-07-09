package com.tmk.vtcmanager.infrastructure.extraction;

import com.tmk.vtcmanager.application.ports.extraction.ContraventionExtraite;
import com.tmk.vtcmanager.application.ports.extraction.ReleveContraventions;
import org.junit.jupiter.api.Test;

import java.io.InputStream;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.Objects;

import static org.assertj.core.api.Assertions.assertThat;

class PdfBoxContraventionExtractorTest {

    private final PdfBoxContraventionExtractor extractor = new PdfBoxContraventionExtractor();

    private ReleveContraventions extraireEchantillon() {
        try (InputStream pdf = getClass().getResourceAsStream("/contraventions/AA-991-SJ-01.pdf")) {
            return extractor.extraire(Objects.requireNonNull(pdf, "PDF échantillon introuvable"));
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    @Test
    void extrait_la_plaque_et_les_quatorze_contraventions() {
        ReleveContraventions releve = extraireEchantillon();

        assertThat(releve.plaque()).isEqualTo("AA-991-SJ-01");
        assertThat(releve.contraventions()).hasSize(14);
    }

    @Test
    void total_des_montants_egal_85000() {
        ReleveContraventions releve = extraireEchantillon();

        BigDecimal total = releve.contraventions().stream()
                .map(ContraventionExtraite::montant)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        assertThat(total).isEqualByComparingTo(new BigDecimal("85000"));
    }

    @Test
    void tous_les_champs_cles_sont_renseignes() {
        ReleveContraventions releve = extraireEchantillon();

        assertThat(releve.contraventions()).allSatisfy(c -> {
            assertThat(c.numeroContravention()).startsWith("C");
            assertThat(c.dateInfraction()).isNotNull();
            assertThat(c.montant()).isGreaterThan(BigDecimal.ZERO);
            assertThat(c.codeInfraction()).isIn("045", "046");
        });
    }

    @Test
    void premiere_ligne_correctement_parsee() {
        ReleveContraventions releve = extraireEchantillon();

        ContraventionExtraite premiere = releve.contraventions().get(0);
        assertThat(premiere.numeroContravention()).isEqualTo("C00000000000146914558");
        assertThat(premiere.codeInfraction()).isEqualTo("046");
        assertThat(premiere.dateInfraction()).isEqualTo(LocalDate.of(2026, 6, 16));
        assertThat(premiere.heureInfraction()).isEqualTo(LocalTime.of(12, 31, 57));
        assertThat(premiere.vitesseRelevee()).isEqualTo(93);
        assertThat(premiere.montant()).isEqualByComparingTo(new BigDecimal("10000"));
    }
}
