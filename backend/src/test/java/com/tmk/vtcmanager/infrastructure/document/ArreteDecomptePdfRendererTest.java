package com.tmk.vtcmanager.infrastructure.document;

import com.tmk.vtcmanager.application.domain.arrete.ArreteCompte;
import com.tmk.vtcmanager.application.domain.arrete.DetteRestanteArrete;
import com.tmk.vtcmanager.application.domain.arrete.LigneArrete;
import com.tmk.vtcmanager.application.domain.arrete.PerimetreArrete;
import com.tmk.vtcmanager.application.domain.arrete.ReglementArrete;
import com.tmk.vtcmanager.application.domain.arrete.SensArrete;
import com.tmk.vtcmanager.application.domain.arrete.StatutArrete;
import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
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
    @DisplayName("liste les cotisations versées, les recettes et contraventions compensées")
    void detailDesDocuments() throws Exception {
        byte[] pdf = renderer.renderDecomptePdf(arrete(PerimetreArrete.VEHICULE, List.of(
                ligne(1, TypeDocumentCreance.COTISATION, SensArrete.CREDIT, 2, "2000"),
                avecReste(ligne(2, TypeDocumentCreance.RECETTE, SensArrete.DEBIT, 5, "15000"), "4000"),
                ligne(3, TypeDocumentCreance.CONTRAVENTION, SensArrete.DEBIT, 7, "10000"))));

        String texte = texte(pdf);
        assertThat(texte).contains("Cotisations versées (1)", "02/09/2026", "2 000",
                "Recettes compensées (1)", "05/09/2026", "15 000",
                "Contraventions compensées (1)", "07/09/2026", "10 000", "Jean Kouassi");
        assertThat(texte).doesNotContain("Pénalités compensées");
    }

    @Test
    @DisplayName("le calcul se lit de haut en bas : repris, versé, réglé, versé au chauffeur, reporté")
    void calculLisible() throws Exception {
        byte[] pdf = renderer.renderDecomptePdf(arrete(PerimetreArrete.CHAUFFEUR, List.of(
                avecReste(ligne(2, TypeDocumentCreance.RECETTE, SensArrete.DEBIT, 5, "15000"), "4000"))));

        String texte = texte(pdf);
        assertThat(texte).contains(
                "Reste dû des périodes précédentes (repris) 5 000 FCFA",
                "Cotisations versées sur la période 60 000 FCFA",
                "Dettes réglées avec ces cotisations 25 000 FCFA",
                "Montant versé au chauffeur 35 000 FCFA",
                "Reste dû, reporté sur l'arrêté suivant 4 000 FCFA",
                "reste dû : 4 000 FCFA");
        assertThat(texte).doesNotContain("Net restitué");
    }

    @Test
    @DisplayName("les dettes restant dues sont détaillées, avec le montant d'origine si entamées")
    void dettesRestantes() throws Exception {
        ArreteCompte a = arrete(PerimetreArrete.VEHICULE, List.of(
                ligne(1, TypeDocumentCreance.COTISATION, SensArrete.CREDIT, 2, "2000")));
        a.setDettesRestantes(List.of(
                DetteRestanteArrete.builder().document(TypeDocumentCreance.RECETTE).documentId(9L)
                        .chauffeurId(1L).chauffeurNom("Jean Kouassi").dateDocument(LocalDate.of(2026, 9, 20))
                        .montantDu(new BigDecimal("21000")).reste(new BigDecimal("6000")).build(),
                DetteRestanteArrete.builder().document(TypeDocumentCreance.CONTRAVENTION).documentId(10L)
                        .dateDocument(LocalDate.of(2026, 9, 25))
                        .montantDu(new BigDecimal("10000")).reste(new BigDecimal("10000")).build()));

        String texte = texte(renderer.renderDecomptePdf(a));
        assertThat(texte).contains("Dettes restant dues (2)", "20/09/2026", "Recette", "6 000",
                "sur 21 000 FCFA dus", "Contravention", "Véhicule (sans chauffeur)",
                "Total reporté sur l'arrêté suivant", "16 000");
    }

    @Test
    @DisplayName("un mois de cotisations journalières déborde sur une page suivante sans rien perdre")
    void multiPages() throws Exception {
        List<LigneArrete> lignes = new ArrayList<>();
        for (int j = 1; j <= 30; j++) {
            lignes.add(ligne(j, TypeDocumentCreance.COTISATION, SensArrete.CREDIT, j, "2000"));
            lignes.add(ligne(100 + j, TypeDocumentCreance.RECETTE, SensArrete.DEBIT, j, "500"));
        }
        byte[] pdf = renderer.renderDecomptePdf(arrete(PerimetreArrete.CHAUFFEUR, lignes));

        String texte = texte(pdf);
        assertThat(pages(pdf)).isGreaterThan(1);
        assertThat(texte).contains("Cotisations versées (30)", "30/09/2026", "60 000",
                "Recettes compensées (30)", "15 000", "1234 AB 01");
    }
}
