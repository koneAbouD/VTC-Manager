package com.tmk.vtcmanager.application.domain.tresorerie;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * Clôture de caisse : comparaison du solde théorique et du comptage physique à
 * une date.
 *
 * <p>L'écart éventuel donne lieu à une opération d'ajustement ({@code operationId})
 * qui réaligne le solde sur le comptage. Cette écriture est passée en <em>compte
 * d'attente</em> : elle n'affecte pas encore le résultat, tant que la décision
 * d'imputation n'est pas prise ({@link StatutImputationEcart}).
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ClotureCaisse {

    private Long id;
    private Long compteId;
    private LocalDate dateCloture;
    private BigDecimal soldeTheorique;
    /** Montant réellement compté. */
    private BigDecimal soldeCompte;
    /** soldeCompte − soldeTheorique : négatif = manquant. */
    private BigDecimal ecart;
    private String motifEcart;
    private Long operationId;

    /** Qui répond du fonds de caisse compté (caissier, gérant du point). */
    private String responsable;

    /** Null quand il n'y a pas d'écart : il n'y a rien à imputer. */
    private StatutImputationEcart imputationStatut;
    private String imputationMotif;
    private LocalDateTime imputeeLe;
    private String imputeePar;
    /** Écriture qui a soldé le compte d'attente. */
    private Long operationImputationId;

    /**
     * Annulation du relevé — saisi à la mauvaise date, sur le mauvais compte,
     * ou d'un montant erroné. Le procès-verbal n'est jamais supprimé : il reste
     * au dossier, marqué, avec son motif et son auteur.
     */
    private LocalDateTime annuleLe;
    private String annulePar;
    private String motifAnnulation;

    /** Vrai si un écart reste à imputer. */
    public boolean attendImputation() {
        return imputationStatut == StatutImputationEcart.EN_ATTENTE;
    }

    /** Vrai si le relevé a été annulé : il ne fait plus foi. */
    public boolean estAnnule() {
        return annuleLe != null;
    }

    /** Vrai si l'écart a déjà été tranché : son annulation demanderait plus. */
    public boolean ecartImpute() {
        return imputationStatut == StatutImputationEcart.PERTE
                || imputationStatut == StatutImputationEcart.RECOUVREE;
    }

    /** Marque le relevé annulé (validation dans le use case). */
    public void annuler(String motif, String auteur) {
        this.annuleLe = LocalDateTime.now();
        this.annulePar = auteur;
        this.motifAnnulation = motif;
    }
}
