package com.tmk.vtcmanager.infrastructure.document;

import com.tmk.vtcmanager.application.domain.arrete.ArreteCompte;
import com.tmk.vtcmanager.application.domain.arrete.ReglementArrete;
import com.tmk.vtcmanager.application.ports.document.ArreteDocumentRenderer;
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
import java.util.Locale;

/** Décompte de restitution des cotisations en PDF (PDFBox 2.x, une page A4). */
@Component
public class ArreteDecomptePdfRenderer implements ArreteDocumentRenderer {

    private static final DateTimeFormatter DATE = DateTimeFormatter.ofPattern("dd/MM/yyyy");
    private static final PDFont REGULAR = PDType1Font.HELVETICA;
    private static final PDFont BOLD = PDType1Font.HELVETICA_BOLD;
    private static final float MARGE = 50;
    private static final float HAUT = 800;

    private final DecimalFormat montantFormat;

    public ArreteDecomptePdfRenderer() {
        DecimalFormatSymbols symboles = new DecimalFormatSymbols(Locale.FRANCE);
        symboles.setGroupingSeparator(' ');
        montantFormat = new DecimalFormat("#,##0", symboles);
    }

    @Override
    public byte[] renderDecomptePdf(ArreteCompte arrete) {
        try (PDDocument document = new PDDocument();
             ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            PDPage page = new PDPage(PDRectangle.A4);
            document.addPage(page);

            try (PDPageContentStream cs = new PDPageContentStream(document, page)) {
                float y = HAUT;
                y = ligne(cs, BOLD, 16, MARGE, y, "Décompte de restitution des cotisations");
                y -= 6;
                y = ligne(cs, REGULAR, 10, MARGE, y,
                        "Référence : " + valeur(arrete.getReference()));
                y = ligne(cs, REGULAR, 10, MARGE, y,
                        (arrete.getPerimetre() != null && arrete.getPerimetre().name().equals("VEHICULE")
                                ? "Véhicule : " : "Chauffeur : ")
                                + valeur(arrete.getPerimetreLibelle()));
                y = ligne(cs, REGULAR, 10, MARGE, y,
                        "Période : " + date(arrete.getPeriodeDebut()) + " au " + date(arrete.getPeriodeFin())
                                + "   |   Arrêté le : " + date(arrete.getDateArrete()));
                if (arrete.getStatut() != null && arrete.getStatut().name().equals("ANNULE")) {
                    y = ligne(cs, BOLD, 11, MARGE, y - 4, "*** ARRÊTÉ ANNULÉ ***");
                }
                y -= 14;

                // En-tête de tableau.
                y = enteteTableau(cs, y);

                double totalCotis = 0, totalCompense = 0, totalNet = 0;
                for (ReglementArrete r : arrete.getReglements()) {
                    y = ligneReglement(cs, y, r);
                    totalCotis += montant(r.getTotalCotisations());
                    totalCompense += montant(r.getTotalCreancesCompensees());
                    totalNet += montant(r.getMontantNet());
                    if (y < 90) break; // sécurité une page
                }

                y -= 6;
                cs.setLineWidth(0.5f);
                cs.moveTo(MARGE, y);
                cs.lineTo(545, y);
                cs.stroke();
                y -= 16;
                colonnes(cs, BOLD, 9.5f, y, "TOTAL",
                        montantFormat.format(totalCotis),
                        montantFormat.format(totalCompense),
                        montantFormat.format(totalNet));

                y -= 30;
                ligne(cs, REGULAR, 9, MARGE, y,
                        "Cotisation = depot detenu pour le chauffeur (hors resultat). "
                                + "Net = fonds - creances compensees.");
            }

            document.save(out);
            return out.toByteArray();
        } catch (IOException e) {
            throw new IllegalStateException("Échec de génération du décompte PDF", e);
        }
    }

    private float enteteTableau(PDPageContentStream cs, float y) throws IOException {
        colonnes(cs, BOLD, 9.5f, y, "Bénéficiaire", "Cotisations", "Compensé", "Net restitué");
        y -= 4;
        cs.setLineWidth(0.5f);
        cs.moveTo(MARGE, y);
        cs.lineTo(545, y);
        cs.stroke();
        return y - 14;
    }

    private float ligneReglement(PDPageContentStream cs, float y, ReglementArrete r) throws IOException {
        String nom = r.getChauffeurNom() != null ? r.getChauffeurNom() : "Chauffeur #" + r.getChauffeurId();
        colonnes(cs, REGULAR, 9.5f, y, tronquer(nom, 34),
                montantFormat.format(montant(r.getTotalCotisations())),
                montantFormat.format(montant(r.getTotalCreancesCompensees())),
                montantFormat.format(montant(r.getMontantNet())));
        float suivant = y - 14;
        if (montant(r.getReliquatReporte()) > 0) {
            suivant = ligne(cs, REGULAR, 8, MARGE + 10, suivant,
                    "reliquat reporté : " + montantFormat.format(montant(r.getReliquatReporte())) + " FCFA");
            suivant -= 4;
        }
        return suivant;
    }

    /** Une rangée à 4 colonnes (libellé à gauche, 3 montants alignés à droite). */
    private void colonnes(PDPageContentStream cs, PDFont font, float taille, float y,
                          String c1, String c2, String c3, String c4) throws IOException {
        texte(cs, font, taille, MARGE, y, c1);
        texteDroite(cs, font, taille, 320, y, c2);
        texteDroite(cs, font, taille, 430, y, c3);
        texteDroite(cs, font, taille, 545, y, c4);
    }

    private float ligne(PDPageContentStream cs, PDFont font, float taille, float x, float y, String s)
            throws IOException {
        texte(cs, font, taille, x, y, s);
        return y - (taille + 5);
    }

    private void texte(PDPageContentStream cs, PDFont font, float taille, float x, float y, String s)
            throws IOException {
        cs.beginText();
        cs.setFont(font, taille);
        cs.newLineAtOffset(x, y);
        cs.showText(s != null ? s : "");
        cs.endText();
    }

    private void texteDroite(PDPageContentStream cs, PDFont font, float taille, float xDroite, float y, String s)
            throws IOException {
        String v = s != null ? s : "";
        float largeur = font.getStringWidth(v) / 1000 * taille;
        texte(cs, font, taille, xDroite - largeur, y, v);
    }

    private String date(LocalDate d) {
        return d != null ? d.format(DATE) : "—";
    }

    private String valeur(String s) {
        return s != null && !s.isBlank() ? s : "—";
    }

    private double montant(BigDecimal b) {
        return b != null ? b.doubleValue() : 0;
    }

    private String tronquer(String s, int max) {
        return s.length() <= max ? s : s.substring(0, max - 2) + "..";
    }
}
