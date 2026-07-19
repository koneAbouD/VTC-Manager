package com.tmk.vtcmanager.application.domain.contravention.reversement;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

/**
 * Aperçu d'une quittance de paiement importée, avant tout reversement : en-tête
 * du document (déjà archivé) et lignes rapprochées avec la base. Rien n'est
 * modifié ici — l'exploitant révise puis confirme.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ApercuReversementQuittance {

    private String numeroLiquidation;
    private String numeroDemande;
    private String demandeur;
    private LocalDate dateQuittance;

    /** Clé de l'objet quittance archivé (traçabilité). */
    private String documentSourcePath;

    @Builder.Default
    private List<LigneReversement> lignes = new ArrayList<>();

    /** Nombre de lignes effectivement reversables. */
    public long nombreAReverser() {
        return lignes.stream().filter(l -> l.getStatut() == StatutLigneReversement.A_REVERSER).count();
    }

    /** Total à reverser = somme des montants système des lignes reversables. */
    public BigDecimal totalAReverser() {
        return lignes.stream()
                .filter(l -> l.getStatut() == StatutLigneReversement.A_REVERSER)
                .map(l -> l.getMontantSysteme() != null ? l.getMontantSysteme() : BigDecimal.ZERO)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }
}
