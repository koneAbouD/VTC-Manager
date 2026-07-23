package com.tmk.vtcmanager.infrastructure.extraction;

import com.tmk.vtcmanager.application.exception.FormatQuittanceNonReconnuException;
import com.tmk.vtcmanager.application.exception.QuittanceIllisibleException;
import com.tmk.vtcmanager.application.ports.extraction.LigneQuittanceReversement;
import com.tmk.vtcmanager.application.ports.extraction.QuittanceReversement;
import com.tmk.vtcmanager.application.ports.extraction.QuittanceReversementExtractorPort;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Extraction d'une quittance de paiement de l'État (QuiPux / DGI).
 *
 * <p>Le texte provient de {@link PdfOcrTextSource} (couche native si présente,
 * sinon OCR d'un scan/photo). Le parsing est tolérant au bruit OCR : chaque
 * ligne de tableau est ancrée sur son <b>numéro de contravention</b>
 * (« C » + chiffres) <b>immédiatement suivi d'une date</b> {@code jj/mm/aaaa}.
 * Cette borne répare les espaces qu'insère l'OCR au milieu du numéro, évite de
 * coller le jour de détection, et écarte les faux positifs (ex. un numéro de
 * compte bancaire de l'en-tête). Plaque, code et montant restent extraits en
 * meilleur effort et peuvent être nuls sans bloquer le reversement.</p>
 */
@Component
public class PdfBoxQuittanceReversementExtractor implements QuittanceReversementExtractorPort {

    private static final Logger log = LoggerFactory.getLogger(PdfBoxQuittanceReversementExtractor.class);

    private static final DateTimeFormatter DATE_TIRET = DateTimeFormatter.ofPattern("dd-MM-yyyy");

    /** Date {@code jj/mm/aaaa} d'une ligne de tableau (détection / verbalisation). */
    private static final Pattern DATE_LIGNE = Pattern.compile("\\d{2}/\\d{2}/\\d{4}");
    /**
     * Numéro de contravention : « C », au moins 15 caractères chiffres/espaces
     * (l'OCR insère parfois des espaces), le tout <b>borné par la date qui suit</b>.
     */
    private static final Pattern NUMERO_BORNE =
            Pattern.compile("C[\\d ]{14,}?\\d(?=\\s*\\d{2}/\\d{2}/\\d{4})");
    private static final Pattern LIQUIDATION = Pattern.compile("(LIQ-?\\w+)");
    private static final Pattern DEMANDE = Pattern.compile("(SOL-?\\w+)");
    private static final Pattern DATE_QUITTANCE = Pattern.compile("(\\d{2}-\\d{2}-\\d{4})");
    private static final Pattern DEMANDEUR = Pattern.compile(
            "Raison sociale\\s*:?\\s*([A-ZÀ-Ÿ][A-ZÀ-Ÿ'’.\\- ]+?)\\s+(?:Type|PAS|Adresse|Num[ée]ro)");
    /** Immatriculation type « AA-991-SJ-01 ». */
    private static final Pattern PLAQUE = Pattern.compile("\\b([A-Z]{2}-\\d{2,4}-[A-Z]{2}-\\d{2})\\b");
    /** Code d'infraction : 3 chiffres isolés (ni précédés ni suivis d'un chiffre/point). */
    private static final Pattern CODE = Pattern.compile("(?<![\\d.])(\\d{3})(?![\\d.])");
    /** Montant à séparateur de milliers par point (« 10.000 », « 5.000 »). */
    private static final Pattern MONTANT_POINT = Pattern.compile("(\\d{1,3}(?:\\.\\d{3})+)");
    /** Montant en entier « collé » (« 10000 », « 5000 »). */
    private static final Pattern MONTANT_ENTIER = Pattern.compile("\\b(\\d{4,})\\b");

    private final PdfOcrTextSource texteSource;

    public PdfBoxQuittanceReversementExtractor(PdfOcrTextSource texteSource) {
        this.texteSource = texteSource;
    }

    @Override
    public QuittanceReversement extraire(InputStream contenu) {
        String texte = texteSource.texte(lireTout(contenu));
        // Aucun texte, même après OCR : document réellement inexploitable.
        if (texte.isBlank()) {
            log.warn("Quittance illisible : aucun texte, même après OCR");
            throw new QuittanceIllisibleException();
        }

        QuittanceReversement quittance = parser(texte);
        log.info("Quittance extraite : liquidation={}, demande={}, {} ligne(s)",
                quittance.numeroLiquidation(), quittance.numeroDemande(), quittance.lignes().size());
        return quittance;
    }

    // ── Parsing (commun natif / OCR) ──────────────────────────────────────────

    private QuittanceReversement parser(String texte) {
        String plat = texte.replaceAll("[ \\t]+", " ");

        String numeroLiquidation = premier(LIQUIDATION, plat);
        String numeroDemande = premier(DEMANDE, plat);
        String demandeur = premier(DEMANDEUR, plat);
        LocalDate date = parseDate(premier(DATE_QUITTANCE, plat));

        List<LigneQuittanceReversement> lignes = new ArrayList<>();
        Set<String> vus = new LinkedHashSet<>();
        for (String brute : texte.split("\\R")) {
            String ligne = brute.replaceAll("[ \\t]+", " ").trim();
            // Une ligne de tableau porte au moins une date jj/mm/aaaa. Ce filtre
            // écarte l'en-tête (dont le numéro de compte bancaire « CI… »).
            if (!DATE_LIGNE.matcher(ligne).find()) {
                continue;
            }
            Matcher num = NUMERO_BORNE.matcher(ligne);
            if (!num.find()) {
                continue;
            }
            String brut = num.group();               // ex. « C00000000000 144654812 » (espaces OCR)
            String numero = brut.replace(" ", "");
            if (numero.length() < 16) {               // C + 15 chiffres minimum
                continue;
            }
            if (!vus.add(numero)) {
                continue; // même numéro rendu sur deux lignes : compté une fois
            }
            String plaque = premier(PLAQUE, ligne);
            // On isole les colonnes (code, montant) en retirant le numéro et la
            // plaque, dont les chiffres pollueraient l'extraction (ex. le « 991 »
            // de « AA-991-SJ-01 » capté comme code d'infraction).
            String reste = ligne.replace(brut, " ");
            if (plaque != null) {
                reste = reste.replace(plaque, " ");
            }
            lignes.add(new LigneQuittanceReversement(
                    numero, plaque, premier(CODE, reste), dernierMontant(reste)));
        }

        // Texte présent mais aucun numéro de contravention détecté → pas une quittance.
        if (lignes.isEmpty()) {
            throw new FormatQuittanceNonReconnuException();
        }
        return new QuittanceReversement(numeroLiquidation, numeroDemande, demandeur, date, lignes);
    }

    // ── Utilitaires ───────────────────────────────────────────────────────────

    /** Dernier montant de la ligne (colonne « Montant à ce jour ») : point d'abord, sinon entier. */
    private BigDecimal dernierMontant(String ligne) {
        String brut = dernier(MONTANT_POINT, ligne);
        if (brut == null) {
            brut = dernier(MONTANT_ENTIER, ligne);
        }
        if (brut == null) {
            return null;
        }
        return new BigDecimal(brut.replace(".", ""));
    }

    private LocalDate parseDate(String valeur) {
        if (valeur == null) {
            return null;
        }
        try {
            return LocalDate.parse(valeur, DATE_TIRET);
        } catch (Exception e) {
            return null;
        }
    }

    private String premier(Pattern pattern, String texte) {
        Matcher m = pattern.matcher(texte);
        return m.find() ? m.group(1 <= m.groupCount() ? 1 : 0).trim() : null;
    }

    private String dernier(Pattern pattern, String texte) {
        Matcher m = pattern.matcher(texte);
        String valeur = null;
        while (m.find()) {
            valeur = m.group(1);
        }
        return valeur;
    }

    private static byte[] lireTout(InputStream in) {
        try {
            return in.readAllBytes();
        } catch (IOException e) {
            throw new UncheckedIOException("Lecture de la quittance impossible", e);
        }
    }
}
