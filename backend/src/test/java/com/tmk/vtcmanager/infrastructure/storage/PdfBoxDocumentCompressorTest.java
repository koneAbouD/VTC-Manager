package com.tmk.vtcmanager.infrastructure.storage;

import com.tmk.vtcmanager.application.ports.storage.DocumentCompressorPort.DocumentCompresse;
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
import java.awt.GradientPaint;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;

import static org.assertj.core.api.Assertions.assertThat;

class PdfBoxDocumentCompressorTest {

    private final PdfBoxDocumentCompressor compresseur =
            new PdfBoxDocumentCompressor(true, 2200, 0.75f, 150, 20);

    @Test
    void image_est_redimensionnee_et_reencodee_en_jpeg() throws Exception {
        // Image 3000×2000 : au-delà de la dimension max (2200).
        byte[] png = pngGradient(3000, 2000);

        DocumentCompresse r = compresseur.compresser(png, "image/png");

        assertThat(r.contentType()).isEqualTo("image/jpeg");
        BufferedImage out = ImageIO.read(new ByteArrayInputStream(r.octets()));
        assertThat(out).isNotNull();
        assertThat(Math.max(out.getWidth(), out.getHeight())).isLessThanOrEqualTo(2200);
        assertThat(r.octets().length).isLessThan(png.length);
    }

    @Test
    void pdf_natif_a_couche_texte_est_conserve_tel_quel() {
        byte[] pdf = pdfTexte("Relevé de contraventions — texte natif extractible");

        DocumentCompresse r = compresseur.compresser(pdf, "application/pdf");

        assertThat(r.octets()).isEqualTo(pdf);           // octets inchangés
        assertThat(r.contentType()).isEqualTo("application/pdf");
    }

    @Test
    void pdf_scanne_est_reencode_en_pdf_valide() throws Exception {
        byte[] pdfImage = pdfImage(2400, 1600);

        DocumentCompresse r = compresseur.compresser(pdfImage, "application/pdf");

        assertThat(r.contentType()).isEqualTo("application/pdf");
        try (PDDocument doc = PDDocument.load(r.octets())) {
            assertThat(doc.getNumberOfPages()).isEqualTo(1); // reste un PDF valide
        }
    }

    @Test
    void compression_desactivee_conserve_l_original() {
        PdfBoxDocumentCompressor off = new PdfBoxDocumentCompressor(false, 2200, 0.75f, 150, 20);
        byte[] pdf = pdfTexte("peu importe");

        DocumentCompresse r = off.compresser(pdf, "application/pdf");

        assertThat(r.octets()).isEqualTo(pdf);
    }

    // ── Générateurs ─────────────────────────────────────────────────────────────

    private static byte[] pngGradient(int w, int h) throws Exception {
        BufferedImage img = new BufferedImage(w, h, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = img.createGraphics();
        g.setPaint(new GradientPaint(0, 0, Color.WHITE, w, h, Color.DARK_GRAY));
        g.fillRect(0, 0, w, h);
        g.dispose();
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        ImageIO.write(img, "png", out);
        return out.toByteArray();
    }

    private static byte[] pdfTexte(String ligne) {
        try (PDDocument doc = new PDDocument()) {
            PDPage page = new PDPage(PDRectangle.A4);
            doc.addPage(page);
            try (PDPageContentStream cs = new PDPageContentStream(doc, page)) {
                cs.setFont(PDType1Font.HELVETICA, 12);
                cs.beginText();
                cs.newLineAtOffset(50, 700);
                cs.showText(ligne);
                cs.endText();
            }
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            doc.save(out);
            return out.toByteArray();
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    private static byte[] pdfImage(int w, int h) throws Exception {
        BufferedImage img = new BufferedImage(w, h, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = img.createGraphics();
        g.setPaint(new GradientPaint(0, 0, Color.WHITE, w, h, Color.GRAY));
        g.fillRect(0, 0, w, h);
        g.dispose();
        try (PDDocument doc = new PDDocument()) {
            PDPage page = new PDPage(new PDRectangle(w, h));
            doc.addPage(page);
            PDImageXObject xo = LosslessFactory.createFromImage(doc, img);
            try (PDPageContentStream cs = new PDPageContentStream(doc, page)) {
                cs.drawImage(xo, 0, 0, w, h);
            }
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            doc.save(out);
            return out.toByteArray();
        }
    }
}
