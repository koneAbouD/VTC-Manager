package com.tmk.vtcmanager.infrastructure.extraction;

import com.tmk.vtcmanager.application.ports.extraction.ContraventionExtractorPort;
import com.tmk.vtcmanager.application.ports.extraction.ContraventionExtraite;
import com.tmk.vtcmanager.application.ports.extraction.ReleveContraventions;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.text.PDFTextStripper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Extraction des relevés de contraventions du Ministère des Transports (CGI),
 * qui sont des PDF <b>natifs</b> (texte extractible) : PDFBox lit le texte, puis
 * on segmente par numéro de contravention et on isole chaque champ par des motifs
 * indépendants de l'ordre des colonnes.
 */
@Component
public class PdfBoxContraventionExtractor implements ContraventionExtractorPort {

    private static final Logger log = LoggerFactory.getLogger(PdfBoxContraventionExtractor.class);

    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter.ofPattern("dd/MM/yyyy");
    private static final DateTimeFormatter HEURE_FMT = DateTimeFormatter.ofPattern("HH:mm:ss");

    private static final Pattern PLAQUE = Pattern.compile("Plaque\\s*:\\s*([A-Z0-9-]+)");
    /** Marqueur de début d'enregistrement : « C » suivi d'au moins 15 chiffres. */
    private static final Pattern NUMERO = Pattern.compile("C\\d{15,}");
    private static final Pattern CODE = Pattern.compile("C\\d{15,}\\s+(\\d{3})\\b");
    private static final Pattern DATE = Pattern.compile("Date\\s*:\\s*(\\d{2}/\\d{2}/\\d{4})");
    private static final Pattern HEURE = Pattern.compile("Heure\\s*:\\s*(\\d{2}:\\d{2}:\\d{2})");
    private static final Pattern VITESSE = Pattern.compile("Vitesse\\s*:\\s*(\\d+)\\s*km/h");
    /** Montant au format à séparateur de milliers par point : « 10.000 », « 5.000 ». */
    private static final Pattern MONTANT = Pattern.compile("(\\d{1,3}(?:\\.\\d{3})+)");
    private static final Pattern DEBITEUR = Pattern.compile("([A-ZÀ-Ÿ][A-ZÀ-Ÿ'’ -]+?)\\s+PAS\\b");

    /** Libellés canoniques des codes d'infraction courants (relevés CGI). */
    private static String libellePourCode(String code) {
        if (code == null) {
            return null;
        }
        return switch (code) {
            case "045" -> "Excès de 10 à 20 km/h sur la vitesse limite";
            case "046" -> "Excès de plus de 20 km/h sur la vitesse limite";
            default -> "Infraction code " + code;
        };
    }

    @Override
    public ReleveContraventions extraire(InputStream contenu) {
        String texte = lireTexte(contenu);
        String plaque = premier(PLAQUE, texte);

        // On ignore le pied de page (« Total à payer », mentions légales) pour ne
        // pas confondre le total avec un montant de ligne.
        String corps = couperAvantTotal(texte);
        // Mise à plat : les champs se repèrent par label, pas par position ligne.
        String plat = corps.replaceAll("\\s+", " ").trim();

        List<ContraventionExtraite> contraventions = new ArrayList<>();
        for (String segment : decouperParEnregistrement(plat)) {
            ContraventionExtraite c = parserSegment(segment);
            if (c != null) {
                contraventions.add(c);
            }
        }
        log.info("Relevé de contraventions extrait : plaque={}, {} ligne(s)", plaque, contraventions.size());
        return new ReleveContraventions(plaque, contraventions);
    }

    private String lireTexte(InputStream contenu) {
        try (PDDocument document = PDDocument.load(contenu)) {
            PDFTextStripper stripper = new PDFTextStripper();
            stripper.setSortByPosition(true);
            return stripper.getText(document);
        } catch (IOException e) {
            throw new UncheckedIOException("Lecture du PDF de contraventions impossible", e);
        }
    }

    private String couperAvantTotal(String texte) {
        int idx = texte.indexOf("Total à payer");
        return idx > 0 ? texte.substring(0, idx) : texte;
    }

    /** Segmente le texte : chaque segment démarre à un numéro de contravention. */
    private List<String> decouperParEnregistrement(String plat) {
        List<String> segments = new ArrayList<>();
        Matcher m = NUMERO.matcher(plat);
        int debut = -1;
        while (m.find()) {
            if (debut >= 0) {
                segments.add(plat.substring(debut, m.start()));
            }
            debut = m.start();
        }
        if (debut >= 0) {
            segments.add(plat.substring(debut));
        }
        return segments;
    }

    private ContraventionExtraite parserSegment(String segment) {
        String numero = premier(NUMERO, segment);
        String dateStr = premier(DATE, segment);
        if (numero == null || dateStr == null) {
            return null; // enregistrement inexploitable
        }
        String code = premier(CODE, segment);
        String heureStr = premier(HEURE, segment);
        String vitesseStr = premier(VITESSE, segment);
        String montantStr = premier(MONTANT, segment);
        String debiteur = premier(DEBITEUR, segment);

        return new ContraventionExtraite(
                numero,
                code,
                libellePourCode(code),
                LocalDate.parse(dateStr, DATE_FMT),
                heureStr != null ? LocalTime.parse(heureStr, HEURE_FMT) : null,
                vitesseStr != null ? Integer.valueOf(vitesseStr) : null,
                null, // lieu : entrelacement colonnes trop instable pour un parsing fiable en MVP
                debiteur != null ? debiteur.trim() : null,
                montantStr != null ? parseMontant(montantStr) : BigDecimal.ZERO
        );
    }

    private static BigDecimal parseMontant(String s) {
        return new BigDecimal(s.replace(".", "").replace(" ", ""));
    }

    /** Premier groupe capturé (ou le match entier si le motif n'a pas de groupe). */
    private static String premier(Pattern pattern, String texte) {
        if (texte == null) {
            return null;
        }
        Matcher m = pattern.matcher(texte);
        if (!m.find()) {
            return null;
        }
        return m.groupCount() >= 1 ? m.group(1) : m.group();
    }
}
