package com.tmk.vtcmanager.application.domain.operation;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.partenaire.Partenaire;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Set;

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
    /**
     * Tiers de l'écriture — le garage payé comptant, l'assureur, le bailleur.
     * Facultatif : toutes les écritures n'ont pas de contrepartie externe.
     */
    private Partenaire partenaire;
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
     * Contravention réglée par cette écriture (remboursement encaissé auprès du
     * chauffeur, ou compensation lors d'un arrêté de compte). Null pour les
     * autres opérations. Sert à repositionner la contravention lorsqu'on annule
     * l'opération.
     */
    private Long contraventionId;

    /**
     * Écriture contre-passée par celle-ci. Renseigné sur l'extourne seule, dont
     * le montant est l'opposé de l'origine — le couple s'annule dans tous les
     * agrégats sans qu'aucune écriture ne disparaisse.
     */
    private Long extourneDeId;

    /**
     * Renseigné à la lecture seulement : {@link #estAnnulable()} — ce que l'état
     * de l'écriture permet — combiné au verrou des arrêtés, que seule la couche
     * de lecture connaît. Faux, le client masque l'action « Annuler ».
     */
    private Boolean annulable;

    /** Motif d'annulation, porté par l'écriture d'origine. */
    private String motifAnnulation;
    private String annulePar;
    private LocalDateTime annuleLe;

    /**
     * Facture fournisseur soldée par cette écriture. Renseigné sur un règlement :
     * la charge étant déjà portée par la facture, la lecture en base engagement
     * écarte ces écritures pour ne pas la compter deux fois.
     */
    private Long facturePartenaireId;

    /** Vrai si cette écriture a été contre-passée. */
    public boolean estExtournee() {
        return annuleLe != null;
    }

    /** Vrai si cette écriture est elle-même une contre-passation. */
    public boolean estUneExtourne() {
        return extourneDeId != null;
    }

    /**
     * Catégories dont l'écriture solde une créance tenue ailleurs : ligne de
     * recette, de cotisation, de pénalité, ou contravention. Leur montant et
     * leur rattachement ne s'éditent pas en place — ils sont le reflet d'un
     * versement enregistré dans le module d'origine.
     */
    private static final Set<String> CODES_ENCAISSEMENT = Set.of(
            "ENCAISSEMENT_RECETTES",
            "ENCAISSEMENT_COTISATIONS",
            "ENCAISSEMENT_PENALITES",
            "CONTRAVENTION_REMBOURSEMENT");

    /** Vrai si l'écriture règle une créance suivie dans un autre module. */
    public boolean estUnEncaissement() {
        return categorie != null && categorie.getCode() != null
                && CODES_ENCAISSEMENT.contains(categorie.getCode().toUpperCase());
    }

    /** Vrai si l'écriture est la dépense née de la complétion d'une maintenance. */
    public boolean estIssueDUneMaintenance() {
        return maintenanceId != null;
    }

    /**
     * Vrai si l'écriture peut encore être retouchée en place.
     *
     * <p>Un encaissement et une dépense de maintenance en sont exclus : leur
     * montant appartient à la ligne ou à l'intervention qui les a produits, et
     * le corriger ici les désaccorderait en silence. La voie est l'annulation,
     * qui repositionne la source, puis la ressaisie.
     */
    public boolean isModifiable() {
        return statut != StatutOperation.ANNULEE
                && !estUneExtourne()
                && !estExtournee()
                && !estUnEncaissement()
                && !estIssueDUneMaintenance();
    }

    /**
     * Vrai si l'écriture peut encore être contre-passée, au seul vu de son état.
     *
     * <p>Trois écritures ne s'annulent pas, et pour la même raison : la
     * correction a déjà eu lieu. Une extourne <em>est</em> la correction —
     * l'extourner rendrait vie à l'origine par la bande. Une écriture extournée
     * l'a déjà reçue — une seconde contre-passation la compterait deux fois en
     * négatif. Une écriture passée {@code ANNULEE} sans extourne — l'annulation
     * d'un arrêté de compte, par exemple — a été neutralisée ailleurs.
     *
     * <p>Le verrou des arrêtés ne se lit pas ici : il porte sur la date, pas sur
     * l'écriture, et se combine à ce jugement dans le drapeau {@code annulable}
     * envoyé au client. La règle métier, elle, tient à cet endroit — les clients
     * n'ont plus à la rejouer chacun de leur côté.
     */
    public boolean estAnnulable() {
        return statut != StatutOperation.ANNULEE
                && !estUneExtourne()
                && !estExtournee();
    }
}
