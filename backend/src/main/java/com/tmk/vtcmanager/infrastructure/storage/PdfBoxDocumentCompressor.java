package com.tmk.vtcmanager.infrastructure.storage;

import com.tmk.vtcmanager.application.ports.storage.DocumentCompressorPort;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.pdmodel.PDPage;
import org.apache.pdfbox.pdmodel.PDPageContentStream;
import org.apache.pdfbox.pdmodel.common.PDRectangle;
import org.apache.pdfbox.pdmodel.graphics.image.JPEGFactory;
import org.apache.pdfbox.pdmodel.graphics.image.PDImageXObject;
import org.apache.pdfbox.rendering.ImageType;
import org.apache.pdfbox.rendering.PDFRenderer;
import org.apache.pdfbox.text.PDFTextStripper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.imageio.IIOImage;
import javax.imageio.ImageIO;
import javax.imageio.ImageWriteParam;
import javax.imageio.ImageWriter;
import javax.imageio.stream.ImageOutputStream;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;

/**
 * Compression des documents (relevés / quittances) avant archivage MinIO.
 *
 * <ul>
 *   <li><b>Image</b> (jpg/png…) : redimensionnée si trop grande puis ré-encodée
 *       en JPEG (perte maîtrisée) ;</li>
 *   <li><b>PDF scanné/photographié</b> (sans couche texte) : chaque page est
 *       rendue puis ré-encodée en JPEG dans un nouveau PDF compact ;</li>
 *   <li><b>PDF natif</b> (avec couche texte, généralement déjà léger) : conservé
 *       tel quel — nécessaire à l'extraction, inutile de le dégrader.</li>
 * </ul>
 *
 * <p>En cas d'échec ou si le résultat n'est pas plus petit, l'original est
 * conservé : la compression ne doit jamais faire échouer un import.</p>
 */
@Component
public class PdfBoxDocumentCompressor implements DocumentCompressorPort {

    private static final Logger log = LoggerFactory.getLogger(PdfBoxDocumentCompressor.class);

    private final boolean enabled;
    private final int maxDimension;
    private final float jpegQuality;
    private final int pdfDpi;
    private final int maxPages;

    public PdfBoxDocumentCompressor(
            @Value("${app.storage.compress.enabled:true}") boolean enabled,
            @Value("${app.storage.compress.max-dimension:2200}") int maxDimension,
            @Value("${app.storage.compress.jpeg-quality:0.75}") float jpegQuality,
            @Value("${app.storage.compress.pdf-dpi:150}") int pdfDpi,
            @Value("${app.storage.compress.max-pages:20}") int maxPages) {
        this.enabled = enabled;
        this.maxDimension = maxDimension;
        this.jpegQuality = jpegQuality;
        this.pdfDpi = pdfDpi;
        this.maxPages = maxPages;
    }

    @Override
    public DocumentCompresse compresser(byte[] octets, String contentType) {
        if (!enabled || octets == null || octets.length == 0) {
            return new DocumentCompresse(octets, contentType);
        }
        try {
            DocumentCompresse resultat = estPdf(octets)
                    ? compresserPdf(octets, contentType)
                    : compresserImage(octets, contentType);
            if (resultat.octets().length < octets.length) {
                log.info("Document compressé pour archivage : {} → {} octets ({}%)",
                        octets.length, resultat.octets().length,
                        100 - (100L * resultat.octets().length / octets.length));
                return resultat;
            }
            return new DocumentCompresse(octets, contentType); // pas plus petit : on garde l'original
        } catch (Exception e) {
            log.warn("Compression impossible, archivage du document original : {}", e.getMessage());
            return new DocumentCompresse(octets, contentType);
        }
    }

    // ── Image ─────────────────────────────────────────────────────────────────

    private DocumentCompresse compresserImage(byte[] octets, String contentType) throws IOException {
        BufferedImage img = ImageIO.read(new ByteArrayInputStream(octets));
        if (img == null) { // format non décodable (HEIC…) : rien à faire
            return new DocumentCompresse(octets, contentType);
        }
        byte[] jpeg = versJpeg(aplatirEtRedimensionner(img));
        return new DocumentCompresse(jpeg, "image/jpeg");
    }

    // ── PDF ───────────────────────────────────────────────────────────────────

    private DocumentCompresse compresserPdf(byte[] octets, String contentType) throws IOException {
        try (PDDocument source = PDDocument.load(octets)) {
            if (aCoucheTexte(source)) {
                return new DocumentCompresse(octets, contentType); // PDF natif : conservé
            }
            PDFRenderer renderer = new PDFRenderer(source);
            int pages = Math.min(source.getNumberOfPages(), maxPages);
            try (PDDocument cible = new PDDocument()) {
                for (int i = 0; i < pages; i++) {
                    BufferedImage rendu =
                            aplatirEtRedimensionner(renderer.renderImageWithDPI(i, pdfDpi, ImageType.RGB));
                    PDPage page = new PDPage(new PDRectangle(rendu.getWidth(), rendu.getHeight()));
                    cible.addPage(page);
                    PDImageXObject image = JPEGFactory.createFromImage(cible, rendu, jpegQuality);
                    try (PDPageContentStream cs = new PDPageContentStream(cible, page)) {
                        cs.drawImage(image, 0, 0, rendu.getWidth(), rendu.getHeight());
                    }
                }
                ByteArrayOutputStream out = new ByteArrayOutputStream();
                cible.save(out);
                return new DocumentCompresse(out.toByteArray(), "application/pdf");
            }
        }
    }

    private boolean aCoucheTexte(PDDocument document) throws IOException {
        PDFTextStripper stripper = new PDFTextStripper();
        stripper.setStartPage(1);
        stripper.setEndPage(Math.min(document.getNumberOfPages(), 2)); // suffit pour trancher
        return !stripper.getText(document).isBlank();
    }

    // ── Utilitaires image ─────────────────────────────────────────────────────

    /** Aplatit l'alpha sur fond blanc et redimensionne si une dimension dépasse la limite. */
    private BufferedImage aplatirEtRedimensionner(BufferedImage src) {
        int w = src.getWidth();
        int h = src.getHeight();
        double facteur = Math.min(1.0, (double) maxDimension / Math.max(w, h));
        int nw = Math.max(1, (int) Math.round(w * facteur));
        int nh = Math.max(1, (int) Math.round(h * facteur));

        BufferedImage rgb = new BufferedImage(nw, nh, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = rgb.createGraphics();
        g.setRenderingHint(RenderingHints.KEY_INTERPOLATION,
                RenderingHints.VALUE_INTERPOLATION_BILINEAR);
        g.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
        g.setColor(java.awt.Color.WHITE);
        g.fillRect(0, 0, nw, nh);
        g.drawImage(src, 0, 0, nw, nh, null);
        g.dispose();
        return rgb;
    }

    private byte[] versJpeg(BufferedImage img) throws IOException {
        ImageWriter writer = ImageIO.getImageWritersByFormatName("jpeg").next();
        ImageWriteParam param = writer.getDefaultWriteParam();
        param.setCompressionMode(ImageWriteParam.MODE_EXPLICIT);
        param.setCompressionQuality(jpegQuality);
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        try (ImageOutputStream ios = ImageIO.createImageOutputStream(out)) {
            writer.setOutput(ios);
            writer.write(null, new IIOImage(img, null, null), param);
        } finally {
            writer.dispose();
        }
        return out.toByteArray();
    }

    private static boolean estPdf(byte[] o) {
        int limite = Math.min(o.length, 1024);
        for (int i = 0; i + 4 <= limite; i++) {
            if (o[i] == '%' && o[i + 1] == 'P' && o[i + 2] == 'D' && o[i + 3] == 'F') {
                return true;
            }
        }
        return false;
    }
}
