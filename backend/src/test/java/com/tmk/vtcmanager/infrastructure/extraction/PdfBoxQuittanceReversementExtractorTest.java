package com.tmk.vtcmanager.infrastructure.extraction;

import com.tmk.vtcmanager.application.exception.FormatQuittanceNonReconnuException;
import com.tmk.vtcmanager.application.exception.QuittanceIllisibleException;
import com.tmk.vtcmanager.application.ports.extraction.LigneQuittanceReversement;
import com.tmk.vtcmanager.application.ports.extraction.QuittanceReversement;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.pdmodel.PDPage;
import org.apache.pdfbox.pdmodel.PDPageContentStream;
import org.apache.pdfbox.pdmodel.common.PDRectangle;
import org.apache.pdfbox.pdmodel.font.PDType1Font;
import org.junit.jupiter.api.Test;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Vérifie l'extraction d'une quittance PDF <b>native</b>. Le document de test est
 * généré à la volée par PDFBox (on ne dispose pas de quittance native réelle — le
 * spécimen fourni est un scan/photo, hors périmètre Phase 1).
 */
class PdfBoxQuittanceReversementExtractorTest {

    private final PdfBoxQuittanceReversementExtractor extractor = new PdfBoxQuittanceReversementExtractor();

    private static final List<String> QUITTANCE = List.of(
            "Numero de liquidation: LIQ-4221283 Numero de demande: SOL42822489 03-07-2026",
            "Nom et prenom(s) / Raison sociale : ABOU-DRAMANE KONE Type et numero de document : PAS: 20AD80087",
            "AA-991-SJ-01 C0000000000014584852 26/12/2025 29/01/2026 - 045 exces - 0 5000 0 5.000",
            "AA-991-SJ-01 C0000000000014654812 04/01/2026 30/01/2026 - 046 exces - 0 10000 0 10.000",
            "AA-991-SJ-01 C0000000000014725132 18/01/2026 03/02/2026 - 046 exces - 0 10000 0 10.000",
            "AA-991-SJ-01 C0000000000014984247 26/01/2026 13/02/2026 - 045 exces - 0 5000 0 5.000",
            "AA-991-SJ-01 C0000000000145042534 11/02/2026 13/02/2026 - 046 exces - 0 10000 0 10.000");

    private QuittanceReversement extraireEchantillon() {
        return extractor.extraire(new ByteArrayInputStream(genererPdf(QUITTANCE)));
    }

    @Test
    void extrait_l_entete_de_la_quittance() {
        QuittanceReversement q = extraireEchantillon();

        assertThat(q.numeroLiquidation()).isEqualTo("LIQ-4221283");
        assertThat(q.numeroDemande()).isEqualTo("SOL42822489");
        assertThat(q.demandeur()).isEqualTo("ABOU-DRAMANE KONE");
        assertThat(q.dateQuittance()).isEqualTo(LocalDate.of(2026, 7, 3));
        assertThat(q.referenceAudit()).isEqualTo("LIQ-4221283");
    }

    @Test
    void extrait_les_cinq_lignes_reglees() {
        QuittanceReversement q = extraireEchantillon();

        assertThat(q.lignes()).hasSize(5);
        assertThat(q.lignes()).extracting(LigneQuittanceReversement::numeroContravention)
                .containsExactly(
                        "C0000000000014584852",
                        "C0000000000014654812",
                        "C0000000000014725132",
                        "C0000000000014984247",
                        "C0000000000145042534");
    }

    @Test
    void code_et_montant_ne_sont_pas_pollues_par_la_plaque() {
        QuittanceReversement q = extraireEchantillon();

        LigneQuittanceReversement premiere = q.lignes().get(0);
        assertThat(premiere.plaque()).isEqualTo("AA-991-SJ-01");
        assertThat(premiere.codeInfraction()).isEqualTo("045"); // pas « 991 »
        assertThat(premiere.montant()).isEqualByComparingTo(new BigDecimal("5000"));
    }

    @Test
    void total_des_montants_egal_40000() {
        QuittanceReversement q = extraireEchantillon();

        BigDecimal total = q.lignes().stream()
                .map(LigneQuittanceReversement::montant)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        assertThat(total).isEqualByComparingTo(new BigDecimal("40000"));
    }

    @Test
    void leve_quittance_illisible_si_pdf_sans_couche_texte() {
        // PDF natif mais sans aucun texte (simule un scan/photo non océrisé).
        byte[] pdfSansTexte = genererPdf(List.of());

        assertThatThrownBy(() -> extractor.extraire(new ByteArrayInputStream(pdfSansTexte)))
                .isInstanceOf(QuittanceIllisibleException.class);
    }

    @Test
    void leve_format_non_reconnu_si_aucun_numero_de_contravention() {
        // PDF lisible mais qui n'est pas une quittance (aucun numero « C…»).
        byte[] autreDocument = genererPdf(List.of(
                "RECU DE PAIEMENT - TAXES DE STATIONNEMENT",
                "Vehicule de transport avec chauffeur (VTC) 1 18000",
                "MONTANT TOTAL PAYE 18000 F CFA"));

        assertThatThrownBy(() -> extractor.extraire(new ByteArrayInputStream(autreDocument)))
                .isInstanceOf(FormatQuittanceNonReconnuException.class);
    }

    // ── Génération d'un PDF natif à couche texte ────────────────────────────────
    private static byte[] genererPdf(List<String> lignes) {
        try (PDDocument doc = new PDDocument()) {
            PDPage page = new PDPage(PDRectangle.A4);
            doc.addPage(page);
            try (PDPageContentStream cs = new PDPageContentStream(doc, page)) {
                cs.setFont(PDType1Font.HELVETICA, 8);
                cs.beginText();
                cs.setLeading(14);
                cs.newLineAtOffset(20, 800);
                for (String ligne : lignes) {
                    cs.showText(ligne);
                    cs.newLine();
                }
                cs.endText();
            }
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            doc.save(out);
            return out.toByteArray();
        } catch (Exception e) {
            throw new RuntimeException("Génération du PDF de test impossible", e);
        }
    }
}
