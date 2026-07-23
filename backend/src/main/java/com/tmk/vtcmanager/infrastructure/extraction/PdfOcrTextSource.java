package com.tmk.vtcmanager.infrastructure.extraction;

import com.fasterxml.jackson.databind.JsonNode;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.rendering.ImageType;
import org.apache.pdfbox.rendering.PDFRenderer;
import org.apache.pdfbox.text.PDFTextStripper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.MediaType;
import org.springframework.http.client.MultipartBodyBuilder;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.util.Arrays;
import java.util.List;
import java.util.stream.Collectors;

/**
 * Source de texte d'un PDF, mutualisée par les extracteurs (relevés de
 * contraventions, quittances de reversement).
 *
 * <ol>
 *   <li><b>Couche texte native</b> lue par PDFBox si présente ;</li>
 *   <li>sinon (scan / photo), chaque page est <b>rendue en image</b> (PDFBox)
 *       puis océrisée par un <b>service OCR HTTP</b> (Tesseract, conteneur
 *       {@code hertzg/tesseract-server}) — voir {@code app.ocr.*}.</li>
 * </ol>
 *
 * <p>Renvoie une chaîne vide si aucun texte n'a pu être obtenu (l'appelant
 * décide alors du message d'erreur). Une panne du service OCR (injoignable)
 * lève en revanche une {@link IllegalStateException} (incident d'exploitation).</p>
 */
@Component
public class PdfOcrTextSource {

    private static final Logger log = LoggerFactory.getLogger(PdfOcrTextSource.class);

    private final boolean ocrEnabled;
    private final String ocrUrl;
    private final List<String> langues;
    private final int dpi;
    private final int maxPages;
    private final RestClient ocrClient;

    public PdfOcrTextSource(
            @Value("${app.ocr.enabled:true}") boolean ocrEnabled,
            @Value("${app.ocr.url:http://localhost:8884}") String ocrUrl,
            @Value("${app.ocr.langs:fra+eng}") String langs,
            @Value("${app.ocr.dpi:200}") int dpi,
            @Value("${app.ocr.max-pages:10}") int maxPages) {
        this.ocrEnabled = ocrEnabled;
        this.ocrUrl = ocrUrl;
        this.langues = Arrays.stream(langs.split("[+, ]+"))
                .map(String::trim).filter(s -> !s.isEmpty()).toList();
        this.dpi = dpi;
        this.maxPages = maxPages;

        // OCR d'une photo = quelques secondes : timeout de lecture généreux.
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(5_000);
        factory.setReadTimeout(120_000);
        this.ocrClient = RestClient.builder().baseUrl(ocrUrl).requestFactory(factory).build();
    }

    /**
     * Texte d'un document téléchargé (PDF) ou photographié (image ou PDF-image) :
     * couche texte native si présente, sinon OCR. {@code ""} si rien d'exploitable.
     */
    public String texte(byte[] octets) {
        // Photo brute (jpg/png…) envoyée directement : aucune couche texte → OCR.
        if (!estPdf(octets)) {
            if (!ocrEnabled) {
                log.warn("Image reçue et OCR désactivé (app.ocr.enabled=false)");
                return "";
            }
            return ocrBytes(octets, typeImage(octets), "photo");
        }
        // PDF : couche texte native (document téléchargé) d'abord, sinon OCR
        // (PDF scanné/photographié sans couche texte).
        try (PDDocument document = PDDocument.load(octets)) {
            String natif = lireTexteNatif(document);
            if (!natif.isBlank()) {
                return natif;
            }
            if (!ocrEnabled) {
                log.warn("PDF sans couche texte et OCR désactivé (app.ocr.enabled=false)");
                return "";
            }
            return ocr(document);
        } catch (IOException e) {
            throw new UncheckedIOException("Lecture du PDF impossible", e);
        }
    }

    /** Vrai si les octets portent la signature PDF « %PDF » (dans les premiers octets). */
    private static boolean estPdf(byte[] o) {
        int limite = Math.min(o.length, 1024);
        for (int i = 0; i + 4 <= limite; i++) {
            if (o[i] == '%' && o[i + 1] == 'P' && o[i + 2] == 'D' && o[i + 3] == 'F') {
                return true;
            }
        }
        return false;
    }

    /** Type MIME d'une image d'après sa signature (JPEG / PNG), sinon flux binaire. */
    private static MediaType typeImage(byte[] o) {
        if (o.length >= 3 && (o[0] & 0xFF) == 0xFF && (o[1] & 0xFF) == 0xD8) {
            return MediaType.IMAGE_JPEG;
        }
        if (o.length >= 8 && (o[0] & 0xFF) == 0x89 && o[1] == 'P' && o[2] == 'N' && o[3] == 'G') {
            return MediaType.IMAGE_PNG;
        }
        return MediaType.APPLICATION_OCTET_STREAM;
    }

    private String lireTexteNatif(PDDocument document) {
        try {
            PDFTextStripper stripper = new PDFTextStripper();
            stripper.setSortByPosition(true);
            return stripper.getText(document);
        } catch (IOException e) {
            throw new UncheckedIOException("Lecture de la couche texte impossible", e);
        }
    }

    // ── OCR (rendu PDFBox + service HTTP Tesseract) ───────────────────────────

    private String ocr(PDDocument document) throws IOException {
        PDFRenderer renderer = new PDFRenderer(document);
        int pages = Math.min(document.getNumberOfPages(), maxPages);
        StringBuilder texte = new StringBuilder();
        for (int i = 0; i < pages; i++) {
            BufferedImage image = renderer.renderImageWithDPI(i, dpi, ImageType.GRAY);
            texte.append(ocrImage(image)).append('\n');
        }
        return texte.toString();
    }

    /** Encode l'image rendue (page PDF) en PNG puis l'océrise. */
    private String ocrImage(BufferedImage image) throws IOException {
        ByteArrayOutputStream png = new ByteArrayOutputStream();
        ImageIO.write(image, "png", png);
        return ocrBytes(png.toByteArray(), MediaType.IMAGE_PNG, "page.png");
    }

    /** Envoie des octets image au service OCR (POST multipart, réponse JSON {data.stdout}). */
    private String ocrBytes(byte[] image, MediaType type, String filename) {
        String options = langues.stream()
                .map(l -> "\"" + l + "\"")
                .collect(Collectors.joining(",", "{\"languages\":[", "]}"));

        MultipartBodyBuilder body = new MultipartBodyBuilder();
        body.part("options", options, MediaType.APPLICATION_JSON);
        body.part("file", new ByteArrayResource(image) {
            @Override
            public String getFilename() {
                return filename;
            }
        }).contentType(type);

        try {
            MultiValueMap<String, ?> parts = body.build();
            JsonNode reponse = ocrClient.post()
                    .uri("/tesseract")
                    .contentType(MediaType.MULTIPART_FORM_DATA)
                    .body(parts)
                    .retrieve()
                    .body(JsonNode.class);
            if (reponse == null) {
                return "";
            }
            JsonNode data = reponse.path("data");
            if (data.path("exit").asInt(0) != 0) {
                log.warn("OCR : Tesseract a renvoyé un code {} — stderr: {}",
                        data.path("exit").asInt(), data.path("stderr").asText(""));
            }
            return data.path("stdout").asText("");
        } catch (RestClientException e) {
            throw new IllegalStateException(
                    "OCR indisponible : le service Tesseract est injoignable à « " + ocrUrl
                            + " ». Démarrez le conteneur OCR (service « tesseract ») ou vérifiez "
                            + "app.ocr.url / OCR_URL. Cause : " + e.getMessage(), e);
        }
    }
}
