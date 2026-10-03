package com.tmk.vtcmanager.infrastructure.document;

import com.tmk.vtcmanager.application.domain.arrete.ArreteCompte;
import com.tmk.vtcmanager.application.domain.arrete.DetteRestanteArrete;
import com.tmk.vtcmanager.application.domain.arrete.LigneArrete;
import com.tmk.vtcmanager.application.domain.arrete.PerimetreArrete;
import com.tmk.vtcmanager.application.domain.arrete.ReglementArrete;
import com.tmk.vtcmanager.application.domain.arrete.SensArrete;
import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
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
import java.util.Comparator;
import java.util.List;
import java.util.Locale;

/**
 * Décompte de restitution des cotisations en PDF (PDFBox 2.x, A4).
 *
 * <p>Le calcul par bénéficiaire, puis le détail des documents de l'arrêté :
 * cotisations versées, recettes, contraventions et pénalités compensées. Le
 * détail peut courir sur plusieurs pages — un mois de cotisations journalières
 * n'y tient pas toujours.</p>
 */
@Component
public class ArreteDecomptePdfRenderer implements ArreteDocumentRenderer {

    private static final DateTimeFormatter DATE = DateTimeFormatter.ofPattern("dd/MM/yyyy");
    private static final PDFont REGULAR = PDType1Font.HELVETICA;
    private static final PDFont BOLD = PDType1Font.HELVETICA_BOLD;
    private static final float MARGE = 50;
    private static final float DROITE = 545;
    private static final float HAUT = 800;
    private static final float BAS = 60;
    private static final float INTERLIGNE = 14;

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
            try (Curseur c = new Curseur(document)) {
                entete(c, arrete);
                synthese(c, arrete);

                boolean parVehicule = arrete.getPerimetre() == PerimetreArrete.VEHICULE;
                detail(c, arrete, "Cotisations versées", TypeDocumentCreance.COTISATION, SensArrete.CREDIT,
                        "Montant", parVehicule);
                detail(c, arrete, "Recettes compensées", TypeDocumentCreance.RECETTE, SensArrete.DEBIT,
                        "Réglé", parVehicule);
                detail(c, arrete, "Contraventions compensées", TypeDocumentCreance.CONTRAVENTION, SensArrete.DEBIT,
                        "Réglé", parVehicule);
                // Rares, mais sans elles la somme des sections ne retomberait pas
                // sur le total compensé de la synthèse.
                detail(c, arrete, "Pénalités compensées", TypeDocumentCreance.PENALITE, SensArrete.DEBIT,
                        "Réglé", parVehicule);

                dettesRestantes(c, arrete, parVehicule);

                notes(c, parVehicule);
            }
            document.save(out);
            return out.toByteArray();
        } catch (IOException e) {
            throw new IllegalStateException("Échec de génération du décompte PDF", e);
        }
    }

    private void entete(Curseur c, ArreteCompte arrete) throws IOException {
        c.ligne(BOLD, 16, MARGE, "Décompte de restitution des cotisations");
        c.y -= 6;
        c.ligne(REGULAR, 10, MARGE, "Référence : " + valeur(arrete.getReference()));
        c.ligne(REGULAR, 10, MARGE,
                (arrete.getPerimetre() == PerimetreArrete.VEHICULE ? "Véhicule : " : "Chauffeur : ")
                        + valeur(arrete.getPerimetreLibelle()));
        c.ligne(REGULAR, 10, MARGE,
                "Période : " + date(arrete.getPeriodeDebut()) + " au " + date(arrete.getPeriodeFin())
                        + "   |   Arrêté le : " + date(arrete.getDateArrete()));
        if (arrete.getStatut() != null && arrete.getStatut().name().equals("ANNULE")) {
            c.y -= 4;
            c.ligne(BOLD, 11, MARGE, "*** ARRÊTÉ ANNULÉ ***");
        }
        c.y -= 14;
    }

    /**
     * Le calcul, posé comme on le ferait à la main, pour chaque bénéficiaire :
     * ce qu'il devait en entrant, ce qu'il a déposé, ce que ses cotisations ont
     * réglé, ce qu'on lui verse et ce qu'il laisse à la période suivante.
     */
    private void synthese(Curseur c, ArreteCompte arrete) throws IOException {
        List<ReglementArrete> reglements = arrete.getReglements();
        for (ReglementArrete r : reglements) {
            String nom = r.getChauffeurNom() != null ? r.getChauffeurNom() : "Chauffeur #" + r.getChauffeurId();
            calcul(c, nom, montant(r.getReliquatAnterieur()), montant(r.getTotalCotisations()),
                    montant(r.getTotalCreancesCompensees()), montant(r.getMontantNet()),
                    montant(r.getReliquatReporte()));
        }
        if (reglements.size() > 1) {
            calcul(c, "Total de l'arrêté",
                    reglements.stream().mapToDouble(r -> montant(r.getReliquatAnterieur())).sum(),
                    reglements.stream().mapToDouble(r -> montant(r.getTotalCotisations())).sum(),
                    reglements.stream().mapToDouble(r -> montant(r.getTotalCreancesCompensees())).sum(),
                    reglements.stream().mapToDouble(r -> montant(r.getMontantNet())).sum(),
                    reglements.stream().mapToDouble(r -> montant(r.getReliquatReporte())).sum());
        }

        // Le solde du compte courant AUJOURD'HUI, et non à la date de l'arrêté :
        // des cotisations ou des dettes ont pu naître depuis.
        c.saut(30);
        double reste = montant(arrete.getResteNet());
        String situation = reste > 0 ? montantFormat.format(reste) + " FCFA de cotisations encore à rendre"
                : reste < 0 ? montantFormat.format(-reste) + " FCFA encore dus"
                : "compte soldé";
        c.ligne(REGULAR, 9.5f, MARGE, "Situation du compte à ce jour : " + situation);
        c.y -= 6;
    }

    private void calcul(Curseur c, String titre, double reliquatAnterieur, double cotisations,
                        double regle, double verse, double reliquat) throws IOException {
        c.saut(110);
        c.ligne(BOLD, 11, MARGE, titre);
        c.y -= 2;
        if (reliquatAnterieur > 0) {
            rangeeCalcul(c, REGULAR, "Reste dû des périodes précédentes (repris)", reliquatAnterieur);
        }
        rangeeCalcul(c, REGULAR, "Cotisations versées sur la période", cotisations);
        rangeeCalcul(c, REGULAR, "–  Dettes réglées avec ces cotisations", regle);
        // Le trait sous la soustraction, puis le résultat sur sa propre ligne.
        c.y += INTERLIGNE - 4;
        c.trait(330);
        c.y -= 13;
        rangeeCalcul(c, BOLD, "=  Montant versé au chauffeur", verse);
        if (reliquat > 0) {
            rangeeCalcul(c, BOLD, "Reste dû, reporté sur l'arrêté suivant", reliquat);
        } else {
            rangeeCalcul(c, REGULAR, "Reste dû sur la période", 0);
        }
        c.y -= 8;
    }

    private void rangeeCalcul(Curseur c, PDFont font, String libelle, double montant) throws IOException {
        c.texte(font, 9.5f, MARGE + 10, libelle);
        c.texteDroite(font, 9.5f, DROITE, montantFormat.format(montant) + " FCFA");
        c.y -= INTERLIGNE;
    }

    /**
     * Liste des documents d'un type, triés par date. Omise si l'arrêté n'en
     * compte aucun. Sur un arrêté véhicule, le chauffeur de chaque ligne est
     * précisé — plusieurs se partagent le fonds ; sur un arrêté chauffeur,
     * c'est le véhicule qui varie.
     */
    private void detail(Curseur c, ArreteCompte arrete, String titre, TypeDocumentCreance type,
                        SensArrete sens, String libelleMontant, boolean parVehicule) throws IOException {
        List<LigneArrete> lignes = arrete.getLignes().stream()
                .filter(l -> l.getDocument() == type && l.getSens() == sens)
                .sorted(Comparator.comparing(LigneArrete::getDateDocument,
                                Comparator.nullsLast(Comparator.naturalOrder()))
                        .thenComparing(LigneArrete::getId, Comparator.nullsLast(Comparator.naturalOrder())))
                .toList();
        if (lignes.isEmpty()) return;

        // Titre, en-tête et au moins une ligne ensemble : jamais de titre orphelin en bas de page.
        c.saut(70);
        c.y -= 8;
        c.ligne(BOLD, 11, MARGE, titre + " (" + lignes.size() + ")");
        c.y -= 2;
        enteteDetail(c, libelleMontant, parVehicule);

        double total = 0;
        for (LigneArrete l : lignes) {
            if (c.saut(2 * INTERLIGNE)) {
                c.ligne(BOLD, 10, MARGE, titre + " (suite)");
                enteteDetail(c, libelleMontant, parVehicule);
            }
            String tiers = parVehicule ? valeur(l.getChauffeurNom()) : valeur(l.getImmatriculation());
            c.texte(REGULAR, 9.5f, MARGE, date(l.getDateDocument()));
            c.texte(REGULAR, 9.5f, 140, tronquer(tiers, 40));
            c.texteDroite(REGULAR, 9.5f, DROITE, montantFormat.format(montant(l.getMontant())));
            c.y -= INTERLIGNE;
            total += montant(l.getMontant());
            // Une créance que le fonds n'a pas soldée : ce qu'elle doit encore,
            // juste dessous, pour qu'on ne la croie pas réglée.
            if (montant(l.getResteApres()) > 0) {
                c.y += 3;
                c.texteDroite(REGULAR, 8, DROITE,
                        "reste dû : " + montantFormat.format(montant(l.getResteApres())) + " FCFA");
                c.y -= INTERLIGNE;
            }
        }

        c.saut(24);
        c.y += 6;
        c.trait();
        c.y -= 12;
        c.texte(BOLD, 9.5f, MARGE, "Total");
        c.texteDroite(BOLD, 9.5f, DROITE, montantFormat.format(total));
        c.y -= INTERLIGNE + 4;
    }

    /**
     * Ce que l'arrêté laisse dû, créance par créance : le détail du « reste dû
     * reporté ». Une créance entamée y figure aussi, pour son seul reste — la
     * rubrique se lit alors d'un bloc, sans recouper les sections au-dessus.
     */
    private void dettesRestantes(Curseur c, ArreteCompte arrete, boolean parVehicule) throws IOException {
        List<DetteRestanteArrete> dettes = arrete.getDettesRestantes();
        if (dettes == null || dettes.isEmpty()) return;

        String titre = "Dettes restant dues";
        c.saut(70);
        c.y -= 8;
        c.ligne(BOLD, 11, MARGE, titre + " (" + dettes.size() + ")");
        c.y -= 2;
        enteteDettes(c, parVehicule);

        double total = 0;
        for (DetteRestanteArrete d : dettes) {
            if (c.saut(2 * INTERLIGNE)) {
                c.ligne(BOLD, 10, MARGE, titre + " (suite)");
                enteteDettes(c, parVehicule);
            }
            String tiers = parVehicule
                    ? (d.getChauffeurId() == null ? "Véhicule (sans chauffeur)" : valeur(d.getChauffeurNom()))
                    : valeur(d.getImmatriculation());
            c.texte(REGULAR, 9.5f, MARGE, date(d.getDateDocument()));
            c.texte(REGULAR, 9.5f, 130, libelleDocument(d.getDocument()));
            c.texte(REGULAR, 9.5f, 230, tronquer(tiers, 30));
            c.texteDroite(REGULAR, 9.5f, DROITE, montantFormat.format(montant(d.getReste())));
            c.y -= INTERLIGNE;
            total += montant(d.getReste());
            // Le montant d'origine, quand la créance a déjà été entamée : sans
            // lui, une recette de 21 000 dont il reste 6 000 passe pour une
            // recette de 6 000.
            if (d.getMontantDu() != null && montant(d.getMontantDu()) > montant(d.getReste())) {
                c.y += 3;
                c.texteDroite(REGULAR, 8, DROITE,
                        "sur " + montantFormat.format(montant(d.getMontantDu())) + " FCFA dus");
                c.y -= INTERLIGNE;
            }
        }

        c.saut(24);
        c.y += 6;
        c.trait();
        c.y -= 12;
        c.texte(BOLD, 9.5f, MARGE, "Total reporté sur l'arrêté suivant");
        c.texteDroite(BOLD, 9.5f, DROITE, montantFormat.format(total));
        c.y -= INTERLIGNE + 4;
    }

    private void enteteDettes(Curseur c, boolean parVehicule) throws IOException {
        c.texte(BOLD, 9.5f, MARGE, "Date");
        c.texte(BOLD, 9.5f, 130, "Document");
        c.texte(BOLD, 9.5f, 230, parVehicule ? "Chauffeur" : "Véhicule");
        c.texteDroite(BOLD, 9.5f, DROITE, "Reste dû");
        c.y -= 4;
        c.trait();
        c.y -= INTERLIGNE;
    }

    private static String libelleDocument(TypeDocumentCreance type) {
        return switch (type) {
            case RECETTE -> "Recette";
            case PENALITE -> "Pénalité";
            case CONTRAVENTION -> "Contravention";
            case COTISATION -> "Cotisation";
        };
    }

    private void enteteDetail(Curseur c, String libelleMontant, boolean parVehicule) throws IOException {
        c.texte(BOLD, 9.5f, MARGE, "Date");
        c.texte(BOLD, 9.5f, 140, parVehicule ? "Chauffeur" : "Véhicule");
        c.texteDroite(BOLD, 9.5f, DROITE, libelleMontant);
        c.y -= 4;
        c.trait();
        c.y -= INTERLIGNE;
    }

    private void notes(Curseur c, boolean parVehicule) throws IOException {
        c.saut(50);
        c.y -= 10;
        c.ligne(REGULAR, 8.5f, MARGE,
                "Les cotisations sont un dépôt gardé pour le chauffeur. À l'arrêté, elles règlent d'abord ses dettes");
        c.ligne(REGULAR, 8.5f, MARGE,
                "(recettes, contraventions, pénalités), de la plus ancienne à la plus récente ; le surplus lui est versé.");
        c.ligne(REGULAR, 8.5f, MARGE,
                "Le reste dû porte sur les dettes datées jusqu'à la fin de la période ; il est repris sur l'arrêté suivant.");
        if (parVehicule) {
            c.ligne(REGULAR, 8.5f, MARGE,
                    "Arrêté par véhicule : les cotisations d'un chauffeur peuvent régler la dette d'un autre chauffeur du véhicule.");
        }
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

    /** Position d'écriture courante ; ouvre une nouvelle page quand la place manque. */
    private static final class Curseur implements AutoCloseable {
        private final PDDocument document;
        private PDPageContentStream cs;
        private float y;

        Curseur(PDDocument document) throws IOException {
            this.document = document;
            nouvellePage();
        }

        private void nouvellePage() throws IOException {
            if (cs != null) cs.close();
            PDPage page = new PDPage(PDRectangle.A4);
            document.addPage(page);
            cs = new PDPageContentStream(document, page);
            y = HAUT;
        }

        /** Passe à la page suivante si {@code hauteur} ne tient plus ; vrai si un saut a eu lieu. */
        boolean saut(float hauteur) throws IOException {
            if (y - hauteur >= BAS) return false;
            nouvellePage();
            return true;
        }

        void ligne(PDFont font, float taille, float x, String s) throws IOException {
            texte(font, taille, x, s);
            y -= taille + 5;
        }

        void trait() throws IOException {
            trait(MARGE);
        }

        void trait(float depuis) throws IOException {
            cs.setLineWidth(0.5f);
            cs.moveTo(depuis, y);
            cs.lineTo(DROITE, y);
            cs.stroke();
        }

        void texte(PDFont font, float taille, float x, String s) throws IOException {
            cs.beginText();
            cs.setFont(font, taille);
            cs.newLineAtOffset(x, y);
            cs.showText(s != null ? s : "");
            cs.endText();
        }

        void texteDroite(PDFont font, float taille, float xDroite, String s) throws IOException {
            String v = s != null ? s : "";
            float largeur = font.getStringWidth(v) / 1000 * taille;
            texte(font, taille, xDroite - largeur, v);
        }

        @Override
        public void close() throws IOException {
            if (cs != null) cs.close();
        }
    }
}
