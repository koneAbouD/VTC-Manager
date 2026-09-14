package com.tmk.vtcmanager.infrastructure.document;

import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.recu.LigneRecuPaiement;
import com.tmk.vtcmanager.application.domain.recu.RecuPaiement;
import com.tmk.vtcmanager.application.domain.versement.NatureImputation;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.text.PDFTextStripper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Le reçu PDF tel que le chauffeur l'ouvre : on le relit comme du texte pour
 * vérifier ce qu'il dit, pas comment il est dessiné.
 */
@DisplayName("Rendu du reçu PDF")
class RecuPaiementPdfRendererTest {

    private final RecuPaiementPdfRenderer renderer = new RecuPaiementPdfRenderer();

    private static LigneRecuPaiement ligne(String libelle, NatureImputation nature, String montant) {
        return new LigneRecuPaiement(libelle, nature, LocalDate.of(2026, 9, 10), LocalDate.of(2026, 9, 11),
                new BigDecimal(montant), "ENC-2026-000501", "MP260911.1523");
    }

    private static RecuPaiement recu(String chauffeur, List<LigneRecuPaiement> lignes, String resteDu) {
        return new RecuPaiement("TMK", chauffeur, "0712345678", List.of("1234 AB 01"),
                List.of(ModePaiement.ESPECES), lignes, resteDu == null ? null : new BigDecimal(resteDu),
                LocalDateTime.of(2026, 9, 14, 11, 32));
    }

    private static String texte(byte[] pdf) throws Exception {
        try (PDDocument document = PDDocument.load(pdf)) {
            return new PDFTextStripper().getText(document);
        }
    }

    @Test
    @DisplayName("le reçu dit qui a payé, combien, pour quoi, et ce qui reste")
    void contenu() throws Exception {
        byte[] pdf = renderer.renderRecuPdf(recu("Jean Kouassi", List.of(
                ligne("Recette", NatureImputation.RECETTE, "15000"),
                ligne("Cotisation carburant", NatureImputation.COTISATION, "2000")), "5000"));

        String texte = texte(pdf);
        assertThat(pdf).startsWith("%PDF".getBytes());
        assertThat(texte).contains("TMK", "REÇU DE PAIEMENT", "Jean Kouassi", "1234 AB 01",
                "17 000 FCFA", "Recette", "Cotisation carburant", "15 000 FCFA", "2 000 FCFA",
                "Payé le 11/09/2026", "En espèces", "réf. MP260911.1523",
                "Reste à payer sur ces créances : 5 000 FCFA");
    }

    @Test
    @DisplayName("un solde nul se dit « à jour »")
    void aJour() throws Exception {
        String texte = texte(renderer.renderRecuPdf(recu("Jean Kouassi",
                List.of(ligne("Recette", NatureImputation.RECETTE, "15000")), "0")));

        assertThat(texte).contains("le chauffeur est à jour").doesNotContain("Reste à payer");
    }

    @Test
    @DisplayName("un long encaissement de masse continue sur une page suivante")
    void plusieursPages() throws Exception {
        List<LigneRecuPaiement> lignes = new ArrayList<>();
        for (int i = 1; i <= 30; i++) {
            lignes.add(ligne("Recette journée " + i, NatureImputation.RECETTE, "15000"));
        }

        byte[] pdf = renderer.renderRecuPdf(recu("Jean Kouassi", lignes, null));

        try (PDDocument document = PDDocument.load(pdf)) {
            assertThat(document.getNumberOfPages()).isGreaterThan(1);
        }
        assertThat(texte(pdf)).contains("Recette journée 30", "reçu de paiement (suite)", "450 000 FCFA");
    }

    @Test
    @DisplayName("un nom hors du jeu latin ne fait pas échouer le reçu")
    void grapheHorsJeuLatin() throws Exception {
        String texte = texte(renderer.renderRecuPdf(recu("Nguyễn Văn An",
                List.of(ligne("Recette", NatureImputation.RECETTE, "15000")), null)));

        assertThat(texte).contains("Nguy").contains("An");
    }
}
