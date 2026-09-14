package com.tmk.vtcmanager.infrastructure.document;

import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.recu.LigneRecuPaiement;
import com.tmk.vtcmanager.application.domain.recu.RecuPaiement;
import com.tmk.vtcmanager.application.ports.document.RecuDocumentRenderer;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.pdmodel.PDPage;
import org.apache.pdfbox.pdmodel.PDPageContentStream;
import org.apache.pdfbox.pdmodel.common.PDRectangle;
import org.apache.pdfbox.pdmodel.font.PDFont;
import org.apache.pdfbox.pdmodel.font.PDType1Font;
import org.springframework.stereotype.Component;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.math.BigDecimal;
import java.text.DecimalFormat;
import java.text.DecimalFormatSymbols;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * Reçu de paiement en PDF (PDFBox 2.x), au format A5.
 *
 * <p>Pensé pour être ouvert sur un téléphone depuis WhatsApp : le montant reçu
 * se lit en premier, dans un bandeau, la ventilation ensuite, le solde pour
 * finir. Au-delà d'une page, le tableau reprend sur la suivante avec son
 * en-tête.
 *
 * <p>Les polices standard de PDF ne couvrent que le jeu latin (WinAnsi) : un
 * caractère hors de ce jeu — un nom écrit dans une autre graphie — est remplacé
 * plutôt que de faire échouer le reçu.
 */
@Component
public class RecuPaiementPdfRenderer implements RecuDocumentRenderer {

    private static final PDFont REGULAR = PDType1Font.HELVETICA;
    private static final PDFont BOLD = PDType1Font.HELVETICA_BOLD;
    private static final PDRectangle FORMAT = PDRectangle.A5;
    private static final float MARGE = 36;
    private static final float DROITE = FORMAT.getWidth() - MARGE;
    private static final float HAUT = FORMAT.getHeight() - MARGE;
    /** Sous cette hauteur, la page suivante : le pied de page garde sa place. */
    private static final float LIMITE_BAS = 92;
    /** Début de la colonne « Journée » du tableau. */
    private static final float COLONNE_JOURNEE = DROITE - 150;

    private static final DateTimeFormatter JOUR = DateTimeFormatter.ofPattern("dd/MM/yyyy");
    private static final DateTimeFormatter HORODATAGE = DateTimeFormatter.ofPattern("dd/MM/yyyy 'à' HH'h'mm");

    private static final float[] ENCRE = {0.10f, 0.12f, 0.16f};
    private static final float[] GRIS = {0.45f, 0.48f, 0.53f};
    private static final float[] VERT = {0.18f, 0.49f, 0.20f};
    private static final float[] VERT_PALE = {0.92f, 0.96f, 0.92f};
    private static final float[] FILET = {0.86f, 0.88f, 0.90f};

    private final DecimalFormat montantFormat;

    public RecuPaiementPdfRenderer() {
        DecimalFormatSymbols symboles = new DecimalFormatSymbols(Locale.FRANCE);
        symboles.setGroupingSeparator(' ');
        montantFormat = new DecimalFormat("#,##0", symboles);
    }

    @Override
    public byte[] renderRecuPdf(RecuPaiement recu) {
        try (PDDocument document = new PDDocument();
             ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            Redaction redaction = new Redaction(document, recu);
            try {
                redaction.entete();
                redaction.parties();
                redaction.bandeauMontant();
                redaction.tableau();
                redaction.solde();
            } finally {
                redaction.fermer();
            }
            document.save(out);
            return out.toByteArray();
        } catch (IOException e) {
            throw new IllegalStateException("Échec de génération du reçu PDF", e);
        }
    }

    /** L'état d'écriture d'un reçu : la page courante et la hauteur où l'on en est. */
    private final class Redaction {

        private final PDDocument document;
        private final RecuPaiement recu;
        private PDPageContentStream cs;
        private float y;
        private int pages;

        Redaction(PDDocument document, RecuPaiement recu) throws IOException {
            this.document = document;
            this.recu = recu;
            nouvellePage();
        }

        void entete() throws IOException {
            texte(BOLD, 22, MARGE, y - 16, valeur(recu.entreprise()), ENCRE);
            texteDroite(BOLD, 9, DROITE, y - 6, "REÇU DE PAIEMENT", VERT);
            texteDroite(REGULAR, 7.5f, DROITE, y - 18, "Émis le " + recu.emisLe().format(HORODATAGE), GRIS);
            y -= 28;
            filet(MARGE, DROITE, y, VERT, 1.2f);
            y -= 22;
        }

        void parties() throws IOException {
            float colonne = MARGE + (DROITE - MARGE) / 2 + 10;
            texte(REGULAR, 7.5f, MARGE, y, "REÇU DE", GRIS);
            texte(REGULAR, 7.5f, colonne, y, recu.vehicules().size() > 1 ? "VÉHICULES" : "VÉHICULE", GRIS);
            y -= 13;
            texte(BOLD, 11, MARGE, y,
                    tronquer(BOLD, 11, valeur(recu.chauffeurNom()), colonne - MARGE - 10), ENCRE);
            texte(BOLD, 11, colonne, y, tronquer(BOLD, 11,
                    recu.vehicules().isEmpty() ? "—" : String.join(", ", recu.vehicules()),
                    DROITE - colonne), ENCRE);
            y -= 12;
            if (renseigne(recu.chauffeurTelephone())) {
                texte(REGULAR, 8.5f, MARGE, y, "Tél. " + recu.chauffeurTelephone(), GRIS);
            }
            y -= 20;
        }

        void bandeauMontant() throws IOException {
            float hauteur = 52;
            rectangle(MARGE, y - hauteur, DROITE - MARGE, hauteur, VERT_PALE);
            texte(REGULAR, 7.5f, MARGE + 12, y - 16, "MONTANT REÇU", VERT);
            texte(BOLD, 20, MARGE + 12, y - 40, montant(recu.total()), ENCRE);
            texteDroite(REGULAR, 8.5f, DROITE - 12, y - 22, payeLe(), ENCRE);
            texteDroite(REGULAR, 8.5f, DROITE - 12, y - 36, modes(), ENCRE);
            y -= hauteur + 24;
        }

        void tableau() throws IOException {
            enteteTableau();
            boolean plusieursDates = recu.datesPaiement().size() > 1;
            for (LigneRecuPaiement ligne : recu.lignes()) {
                if (place(34)) enteteTableau();
                texte(REGULAR, 9, MARGE, y, tronquer(REGULAR, 9, valeur(ligne.libelle()),
                        COLONNE_JOURNEE - MARGE - 10), ENCRE);
                texte(REGULAR, 9, COLONNE_JOURNEE, y, jour(ligne.journee()), ENCRE);
                texteDroite(REGULAR, 9, DROITE, y, montant(ligne.montant()), ENCRE);
                String detail = detail(ligne, plusieursDates);
                if (!detail.isEmpty()) {
                    y -= 10;
                    texte(REGULAR, 7, MARGE, y, tronquer(REGULAR, 7, detail, DROITE - MARGE), GRIS);
                }
                y -= 8;
                filet(MARGE, DROITE, y, FILET, 0.4f);
                y -= 12;
            }
            place(26);
            filet(MARGE, DROITE, y + 4, ENCRE, 0.6f);
            y -= 10;
            texte(BOLD, 10, MARGE, y, "Total reçu", ENCRE);
            texteDroite(BOLD, 10, DROITE, y, montant(recu.total()), ENCRE);
            y -= 24;
        }

        /**
         * Le reste à payer, quand il y en a un. Une créance soldée ne donne lieu
         * à aucune mention : le montant reçu suffit à l'attester.
         */
        void solde() throws IOException {
            if (recu.resteDu() == null || recu.resteDu().signum() <= 0) return;
            place(18);
            texte(BOLD, 10, MARGE, y,
                    "Reste à payer sur ces créances : " + montant(recu.resteDu()), ENCRE);
            y -= 16;
        }

        void fermer() throws IOException {
            if (cs == null) return;
            piedDePage();
            cs.close();
            cs = null;
        }

        private void nouvellePage() throws IOException {
            fermer();
            PDPage page = new PDPage(FORMAT);
            document.addPage(page);
            cs = new PDPageContentStream(document, page);
            pages++;
            y = HAUT;
            if (pages > 1) {
                texte(BOLD, 9, MARGE, y, valeur(recu.entreprise()) + " — reçu de paiement (suite)", GRIS);
                y -= 24;
            }
        }

        private void enteteTableau() throws IOException {
            texte(BOLD, 7.5f, MARGE, y, "DÉSIGNATION", GRIS);
            texte(BOLD, 7.5f, COLONNE_JOURNEE, y, "JOURNÉE", GRIS);
            texteDroite(BOLD, 7.5f, DROITE, y, "MONTANT", GRIS);
            y -= 6;
            filet(MARGE, DROITE, y, ENCRE, 0.6f);
            y -= 14;
        }

        /** Change de page si la hauteur demandée ne tient plus ; dit si c'est arrivé. */
        private boolean place(float hauteur) throws IOException {
            if (y - hauteur >= LIMITE_BAS) return false;
            nouvellePage();
            return true;
        }

        private void piedDePage() throws IOException {
            filet(MARGE, DROITE, 60, FILET, 0.5f);
            texte(REGULAR, 7, MARGE, 48, "Ce reçu atteste que " + valeur(recu.entreprise())
                    + " a reçu les sommes ci-dessus.", GRIS);
            texte(REGULAR, 7, MARGE, 38, "Montants en francs CFA (FCFA) · Document généré par VTC Manager.", GRIS);
            texteDroite(REGULAR, 7, DROITE, 38, "Page " + pages, GRIS);
        }

        private String payeLe() {
            List<LocalDate> dates = recu.datesPaiement();
            if (dates.isEmpty()) return "";
            if (dates.size() == 1) return "Payé le " + jour(dates.get(0));
            return "Payé du " + jour(dates.get(0)) + " au " + jour(dates.get(dates.size() - 1));
        }

        private String modes() {
            List<ModePaiement> modes = recu.modesPaiement();
            if (modes.size() > 1) return "Espèces et Mobile Money";
            if (modes.isEmpty()) return "";
            return modes.get(0) == ModePaiement.MOBILE_MONEY ? "Par Mobile Money" : "En espèces";
        }

        private String detail(LigneRecuPaiement ligne, boolean plusieursDates) {
            List<String> parts = new ArrayList<>();
            if (renseigne(ligne.referenceEcriture())) parts.add("Écriture " + ligne.referenceEcriture());
            if (renseigne(ligne.referencePaiement())) parts.add("réf. " + ligne.referencePaiement());
            if (plusieursDates && ligne.payeLe() != null) parts.add("payé le " + jour(ligne.payeLe()));
            return String.join(" · ", parts);
        }

        // ── Primitives de dessin ────────────────────────────────────────────

        private void texte(PDFont font, float taille, float x, float yy, String s, float[] couleur)
                throws IOException {
            cs.beginText();
            cs.setNonStrokingColor(couleur[0], couleur[1], couleur[2]);
            cs.setFont(font, taille);
            cs.newLineAtOffset(x, yy);
            cs.showText(sur(font, s));
            cs.endText();
        }

        private void texteDroite(PDFont font, float taille, float xDroite, float yy, String s, float[] couleur)
                throws IOException {
            String v = sur(font, s);
            float largeur = font.getStringWidth(v) / 1000 * taille;
            texte(font, taille, xDroite - largeur, yy, v, couleur);
        }

        private void filet(float x1, float x2, float yy, float[] couleur, float epaisseur) throws IOException {
            cs.setStrokingColor(couleur[0], couleur[1], couleur[2]);
            cs.setLineWidth(epaisseur);
            cs.moveTo(x1, yy);
            cs.lineTo(x2, yy);
            cs.stroke();
        }

        private void rectangle(float x, float yy, float largeur, float hauteur, float[] couleur) throws IOException {
            cs.setNonStrokingColor(couleur[0], couleur[1], couleur[2]);
            cs.addRect(x, yy, largeur, hauteur);
            cs.fill();
        }

        private String tronquer(PDFont font, float taille, String s, float largeurMax) throws IOException {
            String v = sur(font, s);
            if (font.getStringWidth(v) / 1000 * taille <= largeurMax) return v;
            while (v.length() > 1 && font.getStringWidth(v + "…") / 1000 * taille > largeurMax) {
                v = v.substring(0, v.length() - 1);
            }
            return v + "…";
        }
    }

    // ── Mise en forme ───────────────────────────────────────────────────────

    private String montant(BigDecimal valeur) {
        return montantFormat.format(valeur != null ? valeur : BigDecimal.ZERO) + " FCFA";
    }

    private static String jour(LocalDate date) {
        return date != null ? date.format(JOUR) : "—";
    }

    private static String valeur(String s) {
        return renseigne(s) ? s : "—";
    }

    private static boolean renseigne(String s) {
        return s != null && !s.isBlank();
    }

    /** Remplace ce que la police ne sait pas écrire, plutôt que d'échouer. */
    private static String sur(PDFont font, String s) {
        if (s == null) return "";
        String normalise = s.replace(' ', ' ').replace(' ', ' ');
        StringBuilder sb = new StringBuilder(normalise.length());
        normalise.codePoints().forEach(cp -> {
            String c = new String(Character.toChars(cp));
            try {
                font.encode(c);
                sb.append(c);
            } catch (IOException | IllegalArgumentException e) {
                sb.append('?');
            }
        });
        return sb.toString();
    }
}
