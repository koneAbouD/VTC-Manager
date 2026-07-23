package com.tmk.vtcmanager.infrastructure.extraction;

import com.tmk.vtcmanager.application.ports.extraction.ContraventionExtractorPort;
import com.tmk.vtcmanager.application.ports.extraction.ContraventionExtraite;
import com.tmk.vtcmanager.application.ports.extraction.ReleveContraventions;
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
 * Extraction des relevés de contraventions du Ministère des Transports (CGI).
 *
 * <p>Le texte provient de {@link PdfOcrTextSource} : couche native si le relevé
 * est un PDF texte, sinon OCR d'un scan/photo. Le texte est ensuite segmenté par
 * numéro de contravention, chaque champ étant isolé par un motif indépendant de
 * l'ordre des colonnes.</p>
 *
 * <p>Le parsing est durci pour l'OCR : le « C » du numéro parfois lu « € » est
 * normalisé, les espaces insérés au milieu du numéro sont réparés (le numéro
 * étant borné par le code à 3 chiffres qui le suit), et les champs date/heure se
 * repèrent sans dépendre de leur libellé. La vitesse garde son libellé
 * {@code Vitesse:} pour ne pas être confondue avec le « 20 km/h » du texte
 * d'infraction. Les relevés photographiés passent par l'écran de revue avant
 * import : l'exploitant vérifie et corrige au besoin.</p>
 */
@Component
public class PdfBoxContraventionExtractor implements ContraventionExtractorPort {

    private static final Logger log = LoggerFactory.getLogger(PdfBoxContraventionExtractor.class);

    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter.ofPattern("dd/MM/yyyy");
    private static final DateTimeFormatter HEURE_FMT = DateTimeFormatter.ofPattern("HH:mm:ss");

    private static final Pattern PLAQUE = Pattern.compile("Plaque\\s*:?\\s*([A-Z0-9-]+)");
    /** Marqueur de début d'enregistrement : « C » suivi d'au moins 15 chiffres. */
    private static final Pattern NUMERO = Pattern.compile("C\\d{15,}");
    private static final Pattern CODE = Pattern.compile("C\\d{15,}\\s+(\\d{3})\\b");
    /** Date d'infraction : la seule date jj/mm/aaaa de l'enregistrement (label-indépendant). */
    private static final Pattern DATE = Pattern.compile("(\\d{2}/\\d{2}/\\d{4})");
    /** Heure d'infraction : le seul hh:mm:ss de l'enregistrement (label-indépendant). */
    private static final Pattern HEURE = Pattern.compile("(\\d{2}:\\d{2}:\\d{2})");
    /** Vitesse : gardée sous label pour ne pas capter le « 20 km/h » du libellé d'infraction. */
    private static final Pattern VITESSE = Pattern.compile("Vitesse\\s*:?\\s*(\\d+)");
    /** Montant au format à séparateur de milliers par point : « 10.000 », « 5.000 ». */
    private static final Pattern MONTANT = Pattern.compile("(\\d{1,3}(?:\\.\\d{3})+)");
    private static final Pattern DEBITEUR = Pattern.compile("([A-ZÀ-Ÿ][A-ZÀ-Ÿ'’ -]+?)\\s+PAS\\b");

    /** Numéro avec espaces OCR, borné par le code à 3 chiffres qui le suit (pour réparation). */
    private static final Pattern NUMERO_ESPACES = Pattern.compile("C[\\d ]{15,}?\\d(?=\\s+\\d{3}\\b)");

    private final PdfOcrTextSource texteSource;

    public PdfBoxContraventionExtractor(PdfOcrTextSource texteSource) {
        this.texteSource = texteSource;
    }

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
        String texte = normaliser(texteSource.texte(lireTout(contenu)));
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

    /** Répare le bruit OCR récurrent : « C » lu « € », espaces au milieu du numéro. */
    private String normaliser(String texte) {
        String t = texte.replace('€', 'C');
        return NUMERO_ESPACES.matcher(t).replaceAll(m -> m.group().replace(" ", ""));
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
                parseDate(dateStr),
                heureStr != null ? parseHeure(heureStr) : null,
                vitesseStr != null ? Integer.valueOf(vitesseStr) : null,
                null, // lieu : entrelacement colonnes trop instable pour un parsing fiable en MVP
                debiteur != null ? debiteur.trim() : null,
                montantStr != null ? parseMontant(montantStr) : BigDecimal.ZERO
        );
    }

    private static LocalDate parseDate(String s) {
        try {
            return LocalDate.parse(s, DATE_FMT);
        } catch (Exception e) {
            return null;
        }
    }

    private static LocalTime parseHeure(String s) {
        try {
            return LocalTime.parse(s, HEURE_FMT);
        } catch (Exception e) {
            return null;
        }
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

    private static byte[] lireTout(InputStream in) {
        try {
            return in.readAllBytes();
        } catch (IOException e) {
            throw new UncheckedIOException("Lecture du relevé impossible", e);
        }
    }
}
