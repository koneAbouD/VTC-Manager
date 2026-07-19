package com.tmk.vtcmanager.infrastructure.extraction;

import com.tmk.vtcmanager.application.ports.extraction.LigneQuittanceReversement;
import com.tmk.vtcmanager.application.ports.extraction.QuittanceReversement;
import com.tmk.vtcmanager.application.ports.extraction.QuittanceReversementExtractorPort;
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
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Extraction d'une quittance de paiement de l'État (QuiPux / DGI) au format
 * <b>PDF natif</b> (couche texte). PDFBox lit le texte ; on repère l'en-tête par
 * label et chaque ligne réglée par son numéro de contravention (« C » + ≥15
 * chiffres). Le numéro suffit au rapprochement : plaque, code et montant sont
 * extraits en meilleur effort et peuvent être nuls sans bloquer le reversement.
 *
 * <p>Phase 1 = PDF natif uniquement. Les photos/scans (sans couche texte)
 * relèvent d'une implémentation OCR distincte (Phase 2).</p>
 */
@Component
public class PdfBoxQuittanceReversementExtractor implements QuittanceReversementExtractorPort {

    private static final Logger log = LoggerFactory.getLogger(PdfBoxQuittanceReversementExtractor.class);

    private static final DateTimeFormatter DATE_TIRET = DateTimeFormatter.ofPattern("dd-MM-yyyy");

    /** Numéro de contravention : « C » suivi d'au moins 15 chiffres. */
    private static final Pattern NUMERO = Pattern.compile("C\\d{15,}");
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

    @Override
    public QuittanceReversement extraire(InputStream contenu) {
        String texte = lireTexte(contenu);
        String plat = texte.replaceAll("[ \\t]+", " ");

        String numeroLiquidation = premier(LIQUIDATION, plat);
        String numeroDemande = premier(DEMANDE, plat);
        String demandeur = premier(DEMANDEUR, plat);
        LocalDate date = parseDate(premier(DATE_QUITTANCE, plat));

        List<LigneQuittanceReversement> lignes = new ArrayList<>();
        Set<String> vus = new LinkedHashSet<>();
        for (String ligne : texte.split("\\R")) {
            Matcher num = NUMERO.matcher(ligne);
            if (!num.find()) {
                continue;
            }
            String numero = num.group();
            if (!vus.add(numero)) {
                continue; // même numéro sur deux lignes de rendu : on ne le compte qu'une fois
            }
            String plaque = premier(PLAQUE, ligne);
            // On isole les colonnes de droite (code, montant) en retirant le numéro
            // et la plaque, dont les chiffres pollueraient l'extraction (ex. le
            // « 991 » de « AA-991-SJ-01 » capté comme code d'infraction).
            String reste = ligne.replaceFirst("C\\d{15,}", " ");
            if (plaque != null) {
                reste = reste.replace(plaque, " ");
            }
            lignes.add(new LigneQuittanceReversement(
                    numero, plaque, premier(CODE, reste), dernierMontant(reste)));
        }

        log.info("Quittance extraite : liquidation={}, demande={}, {} ligne(s)",
                numeroLiquidation, numeroDemande, lignes.size());
        return new QuittanceReversement(numeroLiquidation, numeroDemande, demandeur, date, lignes);
    }

    private String lireTexte(InputStream contenu) {
        try (PDDocument document = PDDocument.load(contenu)) {
            PDFTextStripper stripper = new PDFTextStripper();
            stripper.setSortByPosition(true);
            return stripper.getText(document);
        } catch (IOException e) {
            throw new UncheckedIOException("Lecture de la quittance PDF impossible", e);
        }
    }

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
}
