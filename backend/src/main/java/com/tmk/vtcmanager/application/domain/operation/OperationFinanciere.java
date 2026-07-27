package com.tmk.vtcmanager.application.domain.operation;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OperationFinanciere {

    private Long id;
    private String reference;
    private TypeOperation typeOperation;
    private CategorieOperation categorie;
    private SousCategorieOperation sousCategorie;
    private Chauffeur chauffeur;
    private Vehicule vehicule;
    private BigDecimal montant;
    private ModePaiement modePaiement;
    /**
     * Compte de trésorerie mouvementé. Null toléré (opérations legacy sans
     * compte) : résolu au compte par défaut du type dérivé du mode de
     * paiement lors de la création.
     */
    private Long compteTresorerieId;
    private LocalDate dateOperation;
    /**
     * Date "métier" de référence : pour un encaissement de période, c'est la date
     * de la période concernée (recette/cotisation/faute) et non la date de la
     * transaction. Sert à l'affichage des lignes d'opération. Null = utiliser
     * {@link #dateOperation}.
     */
    private LocalDate dateReference;
    private String commentaire;
    private StatutOperation statut;
    private DetailMaintenance detailMaintenance;

    /**
     * Maintenance à l'origine de cette opération (dépense générée par la
     * complétion d'une maintenance). Null pour les autres opérations. Sert à
     * rouvrir la maintenance lorsqu'on annule l'opération.
     */
    private Long maintenanceId;

    /**
     * Écriture contre-passée par celle-ci. Renseigné sur l'extourne seule, dont
     * le montant est l'opposé de l'origine — le couple s'annule dans tous les
     * agrégats sans qu'aucune écriture ne disparaisse.
     */
    private Long extourneDeId;

    /** Motif d'annulation, porté par l'écriture d'origine. */
    private String motifAnnulation;
    private String annulePar;
    private LocalDateTime annuleLe;

    /** Vrai si cette écriture a été contre-passée. */
    public boolean estExtournee() {
        return annuleLe != null;
    }

    /** Vrai si cette écriture est elle-même une contre-passation. */
    public boolean estUneExtourne() {
        return extourneDeId != null;
    }
}
