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
    /** Écriture qui a porté l'écart au résultat ; null si le responsable rembourse. */
    private Long operationImputationId;
    /** Écriture qui a soldé le compte d'attente lors de l'imputation. */
    private Long operationSoldeAttenteId;

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

    /** Vrai si l'écart a déjà été tranché : le défaire demande de contre-passer. */
    public boolean ecartImpute() {
        return imputationStatut == StatutImputationEcart.PERTE
                || imputationStatut == StatutImputationEcart.RECOUVREE;
    }

    /**
     * Revient sur la décision : l'écart redevient à trancher.
     *
     * <p>Le relevé oublie l'arbitrage, son motif, son auteur et les écritures
     * qu'il avait produites — les garder laisserait croire à une décision
     * encore en vigueur. Rien ne se perd pour autant : ce qui a été décidé puis
     * défait reste lisible au journal, dans le couple écriture / extourne.
     */
    public void retirerImputation() {
        this.imputationStatut = StatutImputationEcart.EN_ATTENTE;
        this.imputationMotif = null;
        this.imputeeLe = null;
        this.imputeePar = null;
        this.operationImputationId = null;
        this.operationSoldeAttenteId = null;
    }

    /**
     * Marque le relevé annulé (validation dans le use case).
     *
     * <p>L'écart cesse du même coup d'attendre une décision : il n'a plus
     * d'existence, son ajustement est contre-passé, et personne n'a plus à
     * trancher entre perte et recouvrement. Le laisser {@code EN_ATTENTE}
     * ferait figurer un arbitrage fantôme dans tout état des écarts à imputer.
     * L'annulation d'un écart déjà tranché, elle, reste interdite — le use case
     * la refuse avant d'arriver ici.
     */
    public void annuler(String motif, String auteur) {
        this.annuleLe = LocalDateTime.now();
        this.annulePar = auteur;
        this.motifAnnulation = motif;
        this.imputationStatut = null;
    }
}
