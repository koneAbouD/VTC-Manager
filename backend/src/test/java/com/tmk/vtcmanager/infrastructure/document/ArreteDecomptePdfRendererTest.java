package com.tmk.vtcmanager.infrastructure.document;

import com.tmk.vtcmanager.application.domain.arrete.ArreteCompte;
import com.tmk.vtcmanager.application.domain.arrete.DetteRestanteArrete;
import com.tmk.vtcmanager.application.domain.arrete.LigneArrete;
import com.tmk.vtcmanager.application.domain.arrete.PerimetreArrete;
import com.tmk.vtcmanager.application.domain.arrete.ReglementArrete;
import com.tmk.vtcmanager.application.domain.arrete.SensArrete;
import com.tmk.vtcmanager.application.domain.arrete.StatutArrete;
import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.text.PDFTextStripper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/** Le décompte d'arrêté relu comme du texte : synthèse puis détail des documents. */
@DisplayName("Rendu du décompte d'arrêté PDF")
class ArreteDecomptePdfRendererTest {

    private final ArreteDecomptePdfRenderer renderer = new ArreteDecomptePdfRenderer();

    private static LigneArrete ligne(long id, TypeDocumentCreance type, SensArrete sens, int jour, String montant) {
        return LigneArrete.builder().id(id).document(type).documentId(id).sens(sens)
                .chauffeurId(1L).chauffeurNom("Jean Kouassi").vehiculeId(1L).immatriculation("1234 AB 01")
                .dateDocument(LocalDate.of(2026, 9, jour)).montant(new BigDecimal(montant)).build();
    }

    private static LigneArrete avecReste(LigneArrete l, String reste) {
        l.setResteApres(new BigDecimal(reste));
        return l;
    }

    private static ArreteCompte arrete(PerimetreArrete perimetre, List<LigneArrete> lignes) {
        return ArreteCompte.builder().id(1L).perimetre(perimetre).perimetreId(1L)
                .perimetreLibelle(perimetre == PerimetreArrete.VEHICULE ? "1234 AB 01" : "Jean Kouassi")
                .periodeDebut(LocalDate.of(2026, 9, 1)).periodeFin(LocalDate.of(2026, 9, 30))
                .dateArrete(LocalDate.of(2026, 10, 1)).reference("ARR-2026-0001").statut(StatutArrete.VALIDE)
                .resteNet(BigDecimal.ZERO).lignes(lignes)
                .reglements(List.of(ReglementArrete.builder().chauffeurId(1L).chauffeurNom("Jean Kouassi")
                        .totalCotisations(new BigDecimal("60000")).totalCreancesCompensees(new BigDecimal("25000"))
                        .montantNet(new BigDecimal("35000")).reliquatReporte(new BigDecimal("4000"))
                        .reliquatAnterieur(new BigDecimal("5000")).build()))
                .build();
    }

    private static String texte(byte[] pdf) throws Exception {
        try (PDDocument document = PDDocument.load(pdf)) {
            return new PDFTextStripper().getText(document);
        }
    }

    private static int pages(byte[] pdf) throws Exception {
        try (PDDocument document = PDDocument.load(pdf)) {
            return document.getNumberOfPages();
        }
    }

    @Test
    @DisplayName("la période couvre le mois entier, même si l'arrêté enregistré porte des bornes resserrées")
    void periodeAuMois() throws Exception {
        ArreteCompte a = arrete(PerimetreArrete.CHAUFFEUR, List.of(
                ligne(1, TypeDocumentCreance.COTISATION, SensArrete.CREDIT, 4, "2000")));
        a.setPeriodeDebut(LocalDate.of(2026, 9, 4));
        a.setPeriodeFin(LocalDate.of(2026, 9, 27));

        String texte = texte(renderer.renderDecomptePdf(a));
        assertThat(texte).contains("Période : du 01/09/2026 au 30/09/2026");
    }

    @Test
    @DisplayName("les cotisations sont listées jour par jour, les jours sans versement signalés")
    void cotisationsJourParJour() throws Exception {
        byte[] pdf = renderer.renderDecomptePdf(arrete(PerimetreArrete.VEHICULE, List.of(
                ligne(1, TypeDocumentCreance.COTISATION, SensArrete.CREDIT, 2, "2000"),
                ligne(2, TypeDocumentCreance.COTISATION, SensArrete.CREDIT, 3, "2000"))));

        String texte = texte(pdf);
        assertThat(texte).contains("1. Cotisations versées", "mer. 02/09/2026 Jean Kouassi 2 000",
                "mar. 01/09/2026 Pas de cotisation versée ce jour",
                "mer. 30/09/2026 Pas de cotisation versée ce jour",
                "Total des cotisations (2 versements) 4 000");
        // 30 jours : 2 versés, 28 vides.
        assertThat(texte.split("Pas de cotisation versée ce jour", -1)).hasSize(29);
    }

    @Test
    @DisplayName("les dettes forment un seul tableau : type, compensé et reste dû côte à côte")
    void tableauDesDettes() throws Exception {
        ArreteCompte a = arrete(PerimetreArrete.VEHICULE, List.of(
                ligne(1, TypeDocumentCreance.COTISATION, SensArrete.CREDIT, 2, "2000"),
                avecReste(ligne(2, TypeDocumentCreance.RECETTE, SensArrete.DEBIT, 5, "15000"), "4000"),
                ligne(3, TypeDocumentCreance.CONTRAVENTION, SensArrete.DEBIT, 7, "10000")));
        // La recette entamée figure aussi parmi les dettes restantes : une seule ligne au tableau.
        a.setDettesRestantes(List.of(
                DetteRestanteArrete.builder().document(TypeDocumentCreance.RECETTE).documentId(2L)
                        .chauffeurId(1L).chauffeurNom("Jean Kouassi").dateDocument(LocalDate.of(2026, 9, 5))
                        .montantDu(new BigDecimal("19000")).reste(new BigDecimal("4000")).build(),
                DetteRestanteArrete.builder().document(TypeDocumentCreance.PENALITE).documentId(10L)
                        .dateDocument(LocalDate.of(2026, 9, 25))
                        .montantDu(new BigDecimal("3000")).reste(new BigDecimal("3000")).build()));

        String texte = texte(renderer.renderDecomptePdf(a));
        assertThat(texte).contains("2. Dettes", "Type", "Compensé", "Reste dû",
                "05/09/2026 Recette Jean Kouassi 15 000 4 000",
                "07/09/2026 Contravention Jean Kouassi 10 000 0",
                "25/09/2026 Pénalité Véhicule (sans chauffeur) 0 3 000",
                "Total des dettes 25 000 7 000");
        assertThat(texte.split("05/09/2026 Recette", -1)).hasSize(2);
        assertThat(texte).doesNotContain("Recettes compensées", "Dettes restant dues");
    }

    @Test
    @DisplayName("le décompte par chauffeur suit les deux tableaux et se lit de haut en bas")
    void calculLisible() throws Exception {
        byte[] pdf = renderer.renderDecomptePdf(arrete(PerimetreArrete.CHAUFFEUR, List.of(
                avecReste(ligne(2, TypeDocumentCreance.RECETTE, SensArrete.DEBIT, 5, "15000"), "4000"))));

        String texte = texte(pdf);
        assertThat(texte.indexOf("1. Cotisations")).isLessThan(texte.indexOf("2. Dettes"));
        assertThat(texte.indexOf("2. Dettes")).isLessThan(texte.indexOf("4. Décompte"));
        assertThat(texte).contains(
                "Reste dû des périodes précédentes (repris) 5 000 FCFA",
                "Cotisations versées sur la période 60 000 FCFA",
                "Dettes réglées avec ces cotisations 25 000 FCFA",
                "Montant versé au chauffeur 35 000 FCFA",
                "Reste dû, reporté sur l'arrêté suivant 4 000 FCFA");
        assertThat(texte).doesNotContain("Net restitué", "Situation du compte");
    }

    @Test
    @DisplayName("un mois de cotisations et de dettes déborde sur une page suivante sans rien perdre")
    void multiPages() throws Exception {
        List<LigneArrete> lignes = new ArrayList<>();
        for (int j = 1; j <= 30; j++) {
            lignes.add(ligne(j, TypeDocumentCreance.COTISATION, SensArrete.CREDIT, j, "2000"));
            lignes.add(ligne(100 + j, TypeDocumentCreance.RECETTE, SensArrete.DEBIT, j, "500"));
        }
        byte[] pdf = renderer.renderDecomptePdf(arrete(PerimetreArrete.CHAUFFEUR, lignes));

        String texte = texte(pdf);
        assertThat(pages(pdf)).isGreaterThan(1);
        assertThat(texte).contains("Total des cotisations (30 versements) 60 000",
                "Total des dettes 15 000 0", "1234 AB 01", "4. Décompte");
        assertThat(texte).doesNotContain("Pas de cotisation versée ce jour");
    }

    private static LigneRecette recetteAnnulee(int jour, String montant, String motif) {
        return LigneRecette.builder().id((long) jour).chauffeurId(1L).chauffeurNom("Jean Kouassi")
                .vehiculeImmatriculation("1234 AB 01").dateRecette(LocalDate.of(2026, 9, jour))
                .montantAttendu(montant != null ? new BigDecimal(montant) : null)
                .statut(StatutLigneRecette.ANNULEE).motifAnnulation(motif).build();
    }

    @Test
    @DisplayName("les recettes annulées sont listées avec leur motif, entre les dettes et le décompte")
    void recettesAnnulees() throws Exception {
        String motifLong = "Véhicule au garage toute la journée suite à une panne d'embrayage constatée "
                + "le matin par le chauffeur, recette non due";
        byte[] pdf = renderer.renderDecomptePdf(arrete(PerimetreArrete.VEHICULE, List.of(
                        ligne(1, TypeDocumentCreance.COTISATION, SensArrete.CREDIT, 2, "2000"))),
                List.of(recetteAnnulee(8, "21000", "Jour férié 🎉"),
                        recetteAnnulee(15, null, motifLong)));

        String texte = texte(pdf);
        assertThat(texte).contains("3. Recettes annulées", "Motif",
                "08/09/2026 Jean Kouassi 21 000 Jour férié ?",
                "15/09/2026 Jean Kouassi — Véhicule au garage",
                "recette non due",
                "Une recette annulée n'est pas due");
        assertThat(texte.indexOf("2. Dettes")).isLessThan(texte.indexOf("3. Recettes annulées"));
        assertThat(texte.indexOf("3. Recettes annulées")).isLessThan(texte.indexOf("4. Décompte"));
    }

    @Test
    @DisplayName("sans recette annulée, la section le dit")
    void aucuneRecetteAnnulee() throws Exception {
        String texte = texte(renderer.renderDecomptePdf(arrete(PerimetreArrete.CHAUFFEUR, List.of())));
        assertThat(texte).contains("3. Recettes annulées", "Aucune recette annulée sur la période.");
    }
}
