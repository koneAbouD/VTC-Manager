package com.tmk.vtcmanager.infrastructure.document;

import com.tmk.vtcmanager.application.domain.arrete.ArreteCompte;
import com.tmk.vtcmanager.application.domain.arrete.DetteRestanteArrete;
import com.tmk.vtcmanager.application.domain.arrete.LigneArrete;
import com.tmk.vtcmanager.application.domain.arrete.PerimetreArrete;
import com.tmk.vtcmanager.application.domain.arrete.ReglementArrete;
import com.tmk.vtcmanager.application.domain.arrete.SensArrete;
import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.ports.document.ArreteDocumentRenderer;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.pdmodel.PDPage;
import org.apache.pdfbox.pdmodel.PDPageContentStream;
import org.apache.pdfbox.pdmodel.common.PDRectangle;
import org.apache.pdfbox.pdmodel.font.PDFont;
import org.apache.pdfbox.pdmodel.font.PDType1Font;
import org.springframework.stereotype.Component;

import java.awt.Color;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.math.BigDecimal;
import java.text.DecimalFormat;
import java.text.DecimalFormatSymbols;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.TreeMap;

/**
 * Décompte de restitution des cotisations en PDF (PDFBox 2.x, A4).
 *
 * <p>Dans l'ordre où on vérifie un arrêté à la main : les cotisations du
 * mois, jour par jour — un jour sans versement se voit ; les dettes, chacune
 * avec ce que les cotisations en ont réglé et ce qu'il en reste ; les recettes
 * annulées avec leur motif, qui expliquent un jour non réclamé ; puis le
 * décompte par chauffeur qui tire le montant versé des tableaux. Le document peut courir sur plusieurs pages.</p>
 */
@Component
public class ArreteDecomptePdfRenderer implements ArreteDocumentRenderer {

    private static final DateTimeFormatter DATE = DateTimeFormatter.ofPattern("dd/MM/yyyy");
    private static final DateTimeFormatter JOUR = DateTimeFormatter.ofPattern("EEE dd/MM/yyyy", Locale.FRENCH);
    private static final PDFont REGULAR = PDType1Font.HELVETICA;
    private static final PDFont BOLD = PDType1Font.HELVETICA_BOLD;
    private static final PDFont ITALIQUE = PDType1Font.HELVETICA_OBLIQUE;
    private static final float MARGE = 50;
    private static final float DROITE = 545;
    private static final float HAUT = 800;
    private static final float BAS = 60;
    private static final float INTERLIGNE = 14;

    // Colonnes du tableau des dettes.
    private static final float COL_TYPE = 135;
    private static final float COL_TIERS = 220;
    private static final float COL_COMPENSE = 465;
    // Colonnes du tableau des recettes annulées.
    private static final float COL_MONTANT_ANNULE = 320;
    private static final float COL_MOTIF = 335;

    private final DecimalFormat montantFormat;

    public ArreteDecomptePdfRenderer() {
        DecimalFormatSymbols symboles = new DecimalFormatSymbols(Locale.FRANCE);
        symboles.setGroupingSeparator(' ');
        montantFormat = new DecimalFormat("#,##0", symboles);
    }

    @Override
    public byte[] renderDecomptePdf(ArreteCompte arrete, List<LigneRecette> recettesAnnulees) {
        try (PDDocument document = new PDDocument();
             ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            try (Curseur c = new Curseur(document)) {
                boolean parVehicule = arrete.getPerimetre() == PerimetreArrete.VEHICULE;
                LocalDate debut = arrete.debutMois();
                LocalDate fin = arrete.finMois();

                entete(c, arrete, debut, fin);
                cotisations(c, arrete, debut, fin, parVehicule);
                dettes(c, arrete, parVehicule);
                recettesAnnulees(c, recettesAnnulees, parVehicule);
                decompte(c, arrete);
                notes(c, parVehicule);
            }
            document.save(out);
            return out.toByteArray();
        } catch (IOException e) {
            throw new IllegalStateException("Échec de génération du décompte PDF", e);
        }
    }

    private void entete(Curseur c, ArreteCompte arrete, LocalDate debut, LocalDate fin) throws IOException {
        c.ligne(BOLD, 16, MARGE, "Décompte de restitution des cotisations");
        c.y -= 6;
        c.ligne(REGULAR, 10, MARGE, "Référence : " + valeur(arrete.getReference()));
        c.ligne(REGULAR, 10, MARGE,
                (arrete.getPerimetre() == PerimetreArrete.VEHICULE ? "Véhicule : " : "Chauffeur : ")
                        + valeur(arrete.getPerimetreLibelle()));
        c.ligne(REGULAR, 10, MARGE,
                "Période : du " + date(debut) + " au " + date(fin)
                        + "   |   Arrêté le : " + date(arrete.getDateArrete()));
        if (arrete.getStatut() != null && arrete.getStatut().name().equals("ANNULE")) {
            c.y -= 4;
            c.ligne(BOLD, 11, MARGE, "*** ARRÊTÉ ANNULÉ ***");
        }
        c.y -= 10;
    }

    // ── 1. Cotisations ──────────────────────────────────────────────────

    /**
     * Chaque jour de la période, versé ou non : c'est le jour vide que le
     * chauffeur conteste, et une liste des seuls versements le cache. Un jour
     * où plusieurs chauffeurs du véhicule ont cotisé compte une ligne chacun.
     */
    private void cotisations(Curseur c, ArreteCompte arrete, LocalDate debut, LocalDate fin,
                             boolean parVehicule) throws IOException {
        Map<LocalDate, List<LigneArrete>> parJour = new TreeMap<>(Comparator.nullsLast(Comparator.naturalOrder()));
        arrete.getLignes().stream()
                .filter(l -> l.getDocument() == TypeDocumentCreance.COTISATION && l.getSens() == SensArrete.CREDIT)
                .sorted(Comparator.comparing(LigneArrete::getId, Comparator.nullsLast(Comparator.naturalOrder())))
                .forEach(l -> parJour.computeIfAbsent(l.getDateDocument(), k -> new ArrayList<>()).add(l));
        if (debut != null && fin != null) {
            for (LocalDate j = debut; !j.isAfter(fin); j = j.plusDays(1)) {
                parJour.putIfAbsent(j, List.of());
            }
        }

        String titre = "1. Cotisations versées";
        titreSection(c, titre);
        enteteCotisations(c, parVehicule);

        double total = 0;
        int nombre = 0;
        for (Map.Entry<LocalDate, List<LigneArrete>> jour : parJour.entrySet()) {
            if (jour.getValue().isEmpty()) {
                if (c.saut(INTERLIGNE)) suiteCotisations(c, titre, parVehicule);
                c.texte(REGULAR, 9.5f, MARGE, jourLibelle(jour.getKey()));
                c.couleur(Color.GRAY);
                c.texte(ITALIQUE, 9, 160, "Pas de cotisation versée ce jour");
                c.couleur(Color.BLACK);
                c.y -= INTERLIGNE;
                continue;
            }
            for (LigneArrete l : jour.getValue()) {
                if (c.saut(INTERLIGNE)) suiteCotisations(c, titre, parVehicule);
                c.texte(REGULAR, 9.5f, MARGE, jourLibelle(jour.getKey()));
                c.texte(REGULAR, 9.5f, 160, tronquer(tiers(l.getChauffeurId(), l.getChauffeurNom(),
                        l.getImmatriculation(), parVehicule), 45));
                c.texteDroite(REGULAR, 9.5f, DROITE, montantFormat.format(montant(l.getMontant())));
                c.y -= INTERLIGNE;
                total += montant(l.getMontant());
                nombre++;
            }
        }

        ligneTotal(c, "Total des cotisations (" + nombre + (nombre > 1 ? " versements)" : " versement)"),
                null, total);
    }

    private void suiteCotisations(Curseur c, String titre, boolean parVehicule) throws IOException {
        c.ligne(BOLD, 10, MARGE, titre + " (suite)");
        enteteCotisations(c, parVehicule);
    }

    private void enteteCotisations(Curseur c, boolean parVehicule) throws IOException {
        c.texte(BOLD, 9.5f, MARGE, "Date");
        c.texte(BOLD, 9.5f, 160, parVehicule ? "Chauffeur" : "Véhicule");
        c.texteDroite(BOLD, 9.5f, DROITE, "Montant");
        c.y -= 4;
        c.trait();
        c.y -= INTERLIGNE;
    }

    // ── 2. Dettes ───────────────────────────────────────────────────────

    /** Une dette du tableau : ce que l'arrêté en a réglé et ce qu'il en reste. */
    private static final class Dette {
        LocalDate date;
        TypeDocumentCreance type;
        Long chauffeurId;
        String chauffeurNom;
        String immatriculation;
        double compense;
        double reste;
    }

    /**
     * Toutes les dettes en un seul tableau — recettes, contraventions,
     * pénalités — qu'elles aient été réglées par les cotisations, en partie
     * ou pas du tout. Une créance entamée apparaît une fois, avec ses deux
     * montants côte à côte.
     *
     * <p>Les lignes compensées (DEBIT) et les dettes restantes se recoupent sur
     * une créance entamée : on les fusionne par document. Pour le reste dû, la
     * dette restante fait foi ; à défaut, le reste figé sur la ligne.</p>
     */
    private void dettes(Curseur c, ArreteCompte arrete, boolean parVehicule) throws IOException {
        Map<String, Dette> dettes = new LinkedHashMap<>();
        for (LigneArrete l : arrete.getLignes()) {
            if (l.getSens() != SensArrete.DEBIT) continue;
            Dette d = dettes.computeIfAbsent(l.getDocument() + ":" + l.getDocumentId(), k -> new Dette());
            d.type = l.getDocument();
            d.date = l.getDateDocument();
            d.chauffeurId = l.getChauffeurId();
            d.chauffeurNom = l.getChauffeurNom();
            d.immatriculation = l.getImmatriculation();
            d.compense += montant(l.getMontant());
            d.reste = Math.max(d.reste, montant(l.getResteApres()));
        }
        if (arrete.getDettesRestantes() != null) {
            for (DetteRestanteArrete r : arrete.getDettesRestantes()) {
                Dette d = dettes.computeIfAbsent(r.getDocument() + ":" + r.getDocumentId(), k -> new Dette());
                d.type = r.getDocument();
                if (d.date == null) d.date = r.getDateDocument();
                if (d.chauffeurNom == null) {
                    d.chauffeurId = r.getChauffeurId();
                    d.chauffeurNom = r.getChauffeurNom();
                }
                if (d.immatriculation == null) d.immatriculation = r.getImmatriculation();
                d.reste = montant(r.getReste());
            }
        }

        List<Dette> lignes = dettes.values().stream()
                .sorted(Comparator.comparing((Dette d) -> d.date, Comparator.nullsLast(Comparator.naturalOrder()))
                        .thenComparing(d -> d.type))
                .toList();

        String titre = "2. Dettes";
        c.y -= 10;
        titreSection(c, titre);
        if (lignes.isEmpty()) {
            c.couleur(Color.GRAY);
            c.ligne(ITALIQUE, 9.5f, MARGE, "Aucune dette sur la période.");
            c.couleur(Color.BLACK);
            return;
        }
        enteteDettes(c, parVehicule);

        double totalCompense = 0;
        double totalReste = 0;
        for (Dette d : lignes) {
            if (c.saut(INTERLIGNE)) {
                c.ligne(BOLD, 10, MARGE, titre + " (suite)");
                enteteDettes(c, parVehicule);
            }
            c.texte(REGULAR, 9.5f, MARGE, date(d.date));
            c.texte(REGULAR, 9.5f, COL_TYPE, libelleDocument(d.type));
            c.texte(REGULAR, 9.5f, COL_TIERS,
                    tronquer(tiers(d.chauffeurId, d.chauffeurNom, d.immatriculation, parVehicule), 30));
            c.texteDroite(REGULAR, 9.5f, COL_COMPENSE, montantFormat.format(d.compense));
            c.texteDroite(d.reste > 0 ? BOLD : REGULAR, 9.5f, DROITE, montantFormat.format(d.reste));
            c.y -= INTERLIGNE;
            totalCompense += d.compense;
            totalReste += d.reste;
        }

        ligneTotal(c, "Total des dettes", totalCompense, totalReste);
    }

    private void enteteDettes(Curseur c, boolean parVehicule) throws IOException {
        c.texte(BOLD, 9.5f, MARGE, "Date");
        c.texte(BOLD, 9.5f, COL_TYPE, "Type");
        c.texte(BOLD, 9.5f, COL_TIERS, parVehicule ? "Chauffeur" : "Véhicule");
        c.texteDroite(BOLD, 9.5f, COL_COMPENSE, "Compensé");
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

    // ── 3. Recettes annulées ────────────────────────────────────────────

    /**
     * Les recettes de la période annulées, avec le motif saisi à l'annulation.
     * Elles ne pèsent pas dans le calcul ; sans elles, le chauffeur ne
     * comprend pas pourquoi un jour travaillé n'apparaît pas parmi les dettes.
     * Le motif peut courir sur plusieurs lignes.
     */
    private void recettesAnnulees(Curseur c, List<LigneRecette> recettes, boolean parVehicule) throws IOException {
        String titre = "3. Recettes annulées";
        c.y -= 10;
        titreSection(c, titre);
        if (recettes == null || recettes.isEmpty()) {
            c.couleur(Color.GRAY);
            c.ligne(ITALIQUE, 9.5f, MARGE, "Aucune recette annulée sur la période.");
            c.couleur(Color.BLACK);
            return;
        }
        enteteRecettesAnnulees(c, parVehicule);

        for (LigneRecette r : recettes) {
            String commentaire = encodable(valeur(r.getMotifAnnulation()), REGULAR);
            List<String> motif = decouper(commentaire, REGULAR, 9.5f, DROITE - COL_MOTIF);
            if (c.saut(motif.size() * INTERLIGNE)) {
                c.ligne(BOLD, 10, MARGE, titre + " (suite)");
                enteteRecettesAnnulees(c, parVehicule);
            }
            c.texte(REGULAR, 9.5f, MARGE, date(r.getDateRecette()));
            c.texte(REGULAR, 9.5f, COL_TYPE, tronquer(tiers(r.getChauffeurId(), r.getChauffeurNom(),
                    r.getVehiculeImmatriculation(), parVehicule), 24));
            c.texteDroite(REGULAR, 9.5f, COL_MONTANT_ANNULE,
                    r.getMontantAttendu() != null ? montantFormat.format(montant(r.getMontantAttendu())) : "—");
            for (String ligne : motif) {
                c.texte(REGULAR, 9.5f, COL_MOTIF, ligne);
                c.y -= INTERLIGNE;
            }
        }
        c.couleur(Color.GRAY);
        c.ligne(ITALIQUE, 8.5f, MARGE, "Une recette annulée n'est pas due : elle n'entre pas dans le décompte.");
        c.couleur(Color.BLACK);
    }

    private void enteteRecettesAnnulees(Curseur c, boolean parVehicule) throws IOException {
        c.texte(BOLD, 9.5f, MARGE, "Date");
        c.texte(BOLD, 9.5f, COL_TYPE, parVehicule ? "Chauffeur" : "Véhicule");
        c.texteDroite(BOLD, 9.5f, COL_MONTANT_ANNULE, "Montant");
        c.texte(BOLD, 9.5f, COL_MOTIF, "Commentaire");
        c.y -= 4;
        c.trait();
        c.y -= INTERLIGNE;
    }

    /** Coupe un texte aux espaces pour qu'il tienne dans {@code largeur} ; un mot trop long est coupé net. */
    private static List<String> decouper(String texte, PDFont font, float taille, float largeur) throws IOException {
        List<String> lignes = new ArrayList<>();
        StringBuilder courante = new StringBuilder();
        for (String mot : texte.replaceAll("\\s+", " ").trim().split(" ")) {
            String essai = courante.isEmpty() ? mot : courante + " " + mot;
            if (largeur(font, taille, essai) <= largeur) {
                courante = new StringBuilder(essai);
                continue;
            }
            if (!courante.isEmpty()) lignes.add(courante.toString());
            courante = new StringBuilder(mot);
            while (courante.length() > 1 && largeur(font, taille, courante.toString()) > largeur) {
                int n = courante.length() - 1;
                while (n > 1 && largeur(font, taille, courante.substring(0, n)) > largeur) n--;
                lignes.add(courante.substring(0, n));
                courante = new StringBuilder(courante.substring(n));
            }
        }
        if (!courante.isEmpty() || lignes.isEmpty()) lignes.add(courante.toString());
        return lignes;
    }

    /**
     * Le motif est saisi librement, au téléphone : un emoji ou un caractère
     * hors WinAnsi ferait échouer tout le PDF. On le remplace par « ? ».
     */
    private static String encodable(String texte, PDFont font) {
        StringBuilder sb = new StringBuilder();
        texte.codePoints().forEach(cp -> {
            String car = new String(Character.toChars(cp));
            try {
                font.encode(car);
                sb.append(car);
            } catch (IOException | IllegalArgumentException e) {
                sb.append(Character.isWhitespace(cp) ? " " : "?");
            }
        });
        return sb.toString();
    }

    private static float largeur(PDFont font, float taille, String s) throws IOException {
        return font.getStringWidth(s) / 1000 * taille;
    }

    // ── 4. Décompte ─────────────────────────────────────────────────────

    /**
     * Le calcul, posé comme on le ferait à la main, pour chaque chauffeur : ce
     * qu'il devait en entrant, ce qu'il a déposé, ce que ses cotisations ont
     * réglé, ce qu'on lui verse et ce qu'il laisse à la période suivante.
     */
    private void decompte(Curseur c, ArreteCompte arrete) throws IOException {
        List<ReglementArrete> reglements = arrete.getReglements();
        if (reglements.isEmpty()) return;
        c.y -= 10;
        c.saut(140);
        titreSection(c, reglements.size() > 1 ? "4. Décompte par chauffeur" : "4. Décompte");
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
    }

    private void calcul(Curseur c, String titre, double reliquatAnterieur, double cotisations,
                        double regle, double verse, double reliquat) throws IOException {
        c.saut(110);
        c.ligne(BOLD, 10.5f, MARGE, titre);
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

    // ── Commun ──────────────────────────────────────────────────────────

    /** Titre de section, avec la place pour l'en-tête et une ligne : jamais de titre orphelin en bas de page. */
    private void titreSection(Curseur c, String titre) throws IOException {
        c.saut(60);
        c.ligne(BOLD, 12, MARGE, titre);
        c.y -= 2;
    }

    /** Trait puis ligne de total ; {@code avantDernier} null pour un tableau à une seule colonne de montant. */
    private void ligneTotal(Curseur c, String libelle, Double avantDernier, double dernier) throws IOException {
        c.saut(24);
        c.y += 6;
        c.trait();
        c.y -= 12;
        c.texte(BOLD, 9.5f, MARGE, libelle);
        if (avantDernier != null) {
            c.texteDroite(BOLD, 9.5f, COL_COMPENSE, montantFormat.format(avantDernier));
        }
        c.texteDroite(BOLD, 9.5f, DROITE, montantFormat.format(dernier));
        c.y -= INTERLIGNE + 4;
    }

    /**
     * Sur un arrêté véhicule, plusieurs chauffeurs se partagent le fonds : on
     * nomme celui de la ligne. Sur un arrêté chauffeur, c'est le véhicule qui
     * varie.
     */
    private String tiers(Long chauffeurId, String chauffeurNom, String immatriculation, boolean parVehicule) {
        if (!parVehicule) return valeur(immatriculation);
        return chauffeurId == null ? "Véhicule (sans chauffeur)" : valeur(chauffeurNom);
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

    private String jourLibelle(LocalDate d) {
        return d != null ? d.format(JOUR) : "—";
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

        void couleur(Color couleur) throws IOException {
            cs.setNonStrokingColor(couleur);
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
