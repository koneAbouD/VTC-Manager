package com.tmk.vtcmanager.infrastructure.extraction;

import com.tmk.vtcmanager.application.ports.extraction.ContraventionExtraite;
import com.tmk.vtcmanager.application.ports.extraction.ReleveContraventions;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.pdmodel.PDPage;
import org.apache.pdfbox.pdmodel.PDPageContentStream;
import org.apache.pdfbox.pdmodel.common.PDRectangle;
import org.apache.pdfbox.pdmodel.graphics.image.LosslessFactory;
import org.apache.pdfbox.pdmodel.graphics.image.PDImageXObject;
import org.junit.jupiter.api.Test;

import javax.imageio.ImageIO;
import java.awt.Color;
import java.awt.Font;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Objects;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

class PdfBoxContraventionExtractorTest {

    private static final String OCR_URL = "http://localhost:8884";

    /** Extracteur avec OCR désactivé (texte natif) pour des tests déterministes. */
    private final PdfBoxContraventionExtractor extractor = new PdfBoxContraventionExtractor(
            new PdfOcrTextSource(false, OCR_URL, "fra+eng", 200, 10));

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

    // ── Cas OCR : relevé image (sans couche texte), joué si le service OCR répond ──

    /** Relevé synthétique (une image sans couche texte → force l'OCR). Format « à plat ». */
    private static final List<String> RELEVE_IMAGE = List.of(
            "Plaque: AA-991-SJ-01 Date de creation: 03/07/2026",
            "C00000000000146914558 046 au-dela de 20 km/h",
            "Date: 16/06/2026 Heure: 12:31:57 Vitesse: 93 km/h 10.000",
            "C00000000000146779048 045 de 10 a 20 km/h",
            "Date: 03/06/2026 Heure: 08:04:55 Vitesse: 84 km/h 5.000",
            "C00000000000146425192 045 de 10 a 20 km/h",
            "Date: 10/05/2026 Heure: 16:37:36 Vitesse: 82 km/h 5.000");

    @Test
    void ocr_lit_un_releve_image_sans_couche_texte() {
        assumeTrue(serviceOcrDisponible(), "Service OCR injoignable (" + OCR_URL + ") : test OCR ignoré");

        PdfBoxContraventionExtractor ocrExtractor = new PdfBoxContraventionExtractor(
                new PdfOcrTextSource(true, OCR_URL, "fra+eng", 200, 10));

        ReleveContraventions releve =
                ocrExtractor.extraire(new ByteArrayInputStream(genererPdfImage(RELEVE_IMAGE)));

        assertThat(releve.plaque()).isEqualTo("AA-991-SJ-01");
        assertThat(releve.contraventions()).hasSize(3);

        ContraventionExtraite premiere = releve.contraventions().get(0);
        assertThat(premiere.numeroContravention()).isEqualTo("C00000000000146914558");
        assertThat(premiere.codeInfraction()).isEqualTo("046");
        assertThat(premiere.dateInfraction()).isEqualTo(LocalDate.of(2026, 6, 16));
        assertThat(premiere.vitesseRelevee()).isEqualTo(93);
        assertThat(premiere.montant()).isEqualByComparingTo(new BigDecimal("10000"));

        BigDecimal total = releve.contraventions().stream()
                .map(ContraventionExtraite::montant)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        assertThat(total).isEqualByComparingTo(new BigDecimal("20000"));
    }

    private static boolean serviceOcrDisponible() {
        try (java.net.Socket s = new java.net.Socket()) {
            s.connect(new java.net.InetSocketAddress("localhost", 8884), 500);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    // ── Génération d'un PDF « image » (aucune couche texte, force l'OCR) ─────────
    private static byte[] genererPdfImage(List<String> lignes) {
        try {
            int largeur = 1800, hauteur = 60 + lignes.size() * 44;
            BufferedImage img = new BufferedImage(largeur, hauteur, BufferedImage.TYPE_INT_RGB);
            Graphics2D g = img.createGraphics();
            g.setRenderingHint(RenderingHints.KEY_TEXT_ANTIALIASING,
                    RenderingHints.VALUE_TEXT_ANTIALIAS_ON);
            g.setColor(Color.WHITE);
            g.fillRect(0, 0, largeur, hauteur);
            g.setColor(Color.BLACK);
            g.setFont(new Font("SansSerif", Font.PLAIN, 24));
            int y = 44;
            for (String ligne : lignes) {
                g.drawString(ligne, 20, y);
                y += 44;
            }
            g.dispose();

            try (PDDocument doc = new PDDocument()) {
                PDPage page = new PDPage(new PDRectangle(largeur, hauteur));
                doc.addPage(page);
                PDImageXObject pdImage = LosslessFactory.createFromImage(doc, img);
                try (PDPageContentStream cs = new PDPageContentStream(doc, page)) {
                    cs.drawImage(pdImage, 0, 0, largeur, hauteur);
                }
                ByteArrayOutputStream out = new ByteArrayOutputStream();
                doc.save(out);
                return out.toByteArray();
            }
        } catch (Exception e) {
            throw new RuntimeException("Génération du PDF image de test impossible", e);
        }
    }
}
