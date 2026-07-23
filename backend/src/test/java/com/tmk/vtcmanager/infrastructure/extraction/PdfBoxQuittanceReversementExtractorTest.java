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
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

/**
 * Vérifie l'extraction d'une quittance PDF. Les cas « natifs » (couche texte)
 * tournent avec l'OCR désactivé, donc sans dépendance externe. Le cas OCR
 * (image sans couche texte) n'est joué que si le service OCR HTTP est joignable
 * (sauté en CI le cas échéant).
 */
class PdfBoxQuittanceReversementExtractorTest {

    private static final String OCR_URL = "http://localhost:8884";

    /** Extracteur avec OCR désactivé (texte natif uniquement) pour des tests déterministes. */
    private final PdfBoxQuittanceReversementExtractor extractor =
            new PdfBoxQuittanceReversementExtractor(
                    new PdfOcrTextSource(false, OCR_URL, "fra+eng", 200, 10));

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
    void ne_confond_pas_le_numero_de_compte_bancaire_de_l_entete() {
        // Le numéro de compte de l'en-tête (« CI… », lu « C1… » par l'OCR) a ≥15
        // chiffres mais N'EST PAS suivi d'une date : il ne doit pas créer de ligne.
        QuittanceReversement q = extractor.extraire(new ByteArrayInputStream(genererPdf(List.of(
                "Comptes Bancaires BBG-C1131010010110277 1000211 - BACI : CI0340100101136382000149",
                "AA-991-SJ-01 C0000000000014584852 26/12/2025 29/01/2026 - 045 exces - 0 5000 0 5.000"))));

        assertThat(q.lignes()).extracting(LigneQuittanceReversement::numeroContravention)
                .containsExactly("C0000000000014584852");
    }

    @Test
    void leve_quittance_illisible_si_pdf_sans_couche_texte_et_ocr_off() {
        // PDF natif mais sans aucun texte (simule un scan/photo non océrisé), OCR off.
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

    // ── Cas OCR : image sans couche texte, joué si le service OCR est joignable ──

    @Test
    void ocr_lit_une_quittance_image_sans_couche_texte() {
        assumeTrue(serviceOcrDisponible(), "Service OCR injoignable (" + OCR_URL + ") : test OCR ignoré");

        PdfBoxQuittanceReversementExtractor ocrExtractor =
                new PdfBoxQuittanceReversementExtractor(
                        new PdfOcrTextSource(true, OCR_URL, "fra+eng", 200, 10));
        byte[] pdfImage = genererPdfImage(QUITTANCE);

        QuittanceReversement q = ocrExtractor.extraire(new ByteArrayInputStream(pdfImage));

        assertThat(q.numeroLiquidation()).isEqualTo("LIQ-4221283");
        assertThat(q.numeroDemande()).isEqualTo("SOL42822489");
        assertThat(q.lignes()).hasSize(5);
        assertThat(q.lignes()).extracting(LigneQuittanceReversement::numeroContravention)
                .contains("C0000000000014584852", "C0000000000145042534");
    }

    @Test
    void ocr_lit_une_image_brute_photo_sans_pdf() {
        assumeTrue(serviceOcrDisponible(), "Service OCR injoignable (" + OCR_URL + ") : test OCR ignoré");

        PdfBoxQuittanceReversementExtractor ocrExtractor =
                new PdfBoxQuittanceReversementExtractor(
                        new PdfOcrTextSource(true, OCR_URL, "fra+eng", 200, 10));

        // Octets d'une image PNG brute (une photo), sans enveloppe PDF.
        QuittanceReversement q =
                ocrExtractor.extraire(new ByteArrayInputStream(genererPngBrut(QUITTANCE)));

        assertThat(q.numeroLiquidation()).isEqualTo("LIQ-4221283");
        assertThat(q.lignes()).hasSize(5);
    }

    private static boolean serviceOcrDisponible() {
        try (java.net.Socket s = new java.net.Socket()) {
            s.connect(new java.net.InetSocketAddress("localhost", 8884), 500);
            return true;
        } catch (Exception e) {
            return false;
        }
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

    // ── Génération d'un PDF « image » (aucune couche texte, force l'OCR) ─────────
    private static byte[] genererPdfImage(List<String> lignes) {
        try {
            // 1. Rendu des lignes dans une image (texte net, grande taille).
            int largeur = 1700, hauteur = 60 + lignes.size() * 40;
            BufferedImage img = new BufferedImage(largeur, hauteur, BufferedImage.TYPE_INT_RGB);
            Graphics2D g = img.createGraphics();
            g.setRenderingHint(RenderingHints.KEY_TEXT_ANTIALIASING,
                    RenderingHints.VALUE_TEXT_ANTIALIAS_ON);
            g.setColor(Color.WHITE);
            g.fillRect(0, 0, largeur, hauteur);
            g.setColor(Color.BLACK);
            g.setFont(new Font("SansSerif", Font.PLAIN, 22));
            int y = 40;
            for (String ligne : lignes) {
                g.drawString(ligne, 20, y);
                y += 40;
            }
            g.dispose();

            // 2. Image intégrée dans un PDF (aucune couche texte).
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

    /** Génère une image PNG brute (une « photo »), sans enveloppe PDF. */
    private static byte[] genererPngBrut(List<String> lignes) {
        try {
            int largeur = 1700, hauteur = 60 + lignes.size() * 40;
            BufferedImage img = new BufferedImage(largeur, hauteur, BufferedImage.TYPE_INT_RGB);
            Graphics2D g = img.createGraphics();
            g.setRenderingHint(RenderingHints.KEY_TEXT_ANTIALIASING,
                    RenderingHints.VALUE_TEXT_ANTIALIAS_ON);
            g.setColor(Color.WHITE);
            g.fillRect(0, 0, largeur, hauteur);
            g.setColor(Color.BLACK);
            g.setFont(new Font("SansSerif", Font.PLAIN, 22));
            int y = 40;
            for (String ligne : lignes) {
                g.drawString(ligne, 20, y);
                y += 40;
            }
            g.dispose();
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            ImageIO.write(img, "png", out);
            return out.toByteArray();
        } catch (Exception e) {
            throw new RuntimeException("Génération du PNG de test impossible", e);
        }
    }
}
