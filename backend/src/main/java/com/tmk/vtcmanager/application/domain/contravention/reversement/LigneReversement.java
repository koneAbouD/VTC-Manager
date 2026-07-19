package com.tmk.vtcmanager.application.domain.contravention.reversement;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * Une ligne de quittance rapprochée : ce qui est lu sur le document (numéro,
 * plaque, code, montant réglé) et ce qui est résolu en base (id, montant
 * système, classement). Seules les lignes {@link StatutLigneReversement#A_REVERSER}
 * portent un {@link #contraventionId} exploitable pour le reversement.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class LigneReversement {

    // ── Lu sur la quittance ────────────────────────────────────────────────
    private String numeroContravention;
    private String plaque;
    private String codeInfraction;
    private BigDecimal montantQuittance;

    // ── Résolu en base ─────────────────────────────────────────────────────
    /** Id de la contravention correspondante ; null si introuvable. */
    private Long contraventionId;
    /** Montant enregistré côté système ; null si introuvable. */
    private BigDecimal montantSysteme;

    private StatutLigneReversement statut;

    /** Vrai si le montant de la quittance diffère du montant système (à vérifier). */
    private boolean montantDivergent;
}
