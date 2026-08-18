package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = OperationFinanciereEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class OperationFinanciereEntity extends AbstractEcritureAuditEntity {

    public static final String TABLE_NAME = "operations_financieres";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 30)
    private String reference;

    @Enumerated(EnumType.STRING)
    @Column(name = "type_operation", nullable = false, length = 20)
    private TypeOperation typeOperation;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "categorie_id")
    private CategorieOperationEntity categorie;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "sous_categorie_id")
    private SousCategorieOperationEntity sousCategorie;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "chauffeur_id")
    private ChauffeurEntity chauffeur;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "vehicule_id")
    private VehiculeEntity vehicule;

    /** Tiers de l'écriture (garage, assureur, bailleur…), facultatif. */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "partenaire_id")
    private PartenaireEntity partenaire;

    @Column(nullable = false, precision = 19, scale = 2)
    private BigDecimal montant;

    @Enumerated(EnumType.STRING)
    @Column(name = "mode_paiement", length = 20)
    private ModePaiement modePaiement;

    @Column(name = "compte_tresorerie_id")
    private Long compteTresorerieId;

    @Column(name = "date_operation", nullable = false)
    private LocalDate dateOperation;

    @Column(name = "date_reference")
    private LocalDate dateReference;

    @Column(columnDefinition = "TEXT")
    private String commentaire;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private StatutOperation statut;

    @OneToOne(cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @JoinColumn(name = "detail_maintenance_id")
    private DetailMaintenanceEntity detailMaintenance;

    /** Maintenance d'origine (dépense issue d'une complétion de maintenance). */
    @Column(name = "maintenance_id")
    private Long maintenanceId;

    /** Contravention réglée par cette écriture (remboursement ou compensation). */
    @Column(name = "contravention_id")
    private Long contraventionId;

    /**
     * Écriture contre-passée par celle-ci. Renseigné uniquement sur une
     * extourne, dont le montant est négatif : le couple origine + extourne
     * s'annule dans tous les agrégats.
     */
    @Column(name = "extourne_de_id")
    private Long extourneDeId;

    /** Facture fournisseur soldée par cette écriture (règlement). */
    @Column(name = "facture_partenaire_id")
    private Long facturePartenaireId;

    /** Motif saisi lors de l'annulation, porté par l'écriture d'origine. */
    @Column(name = "motif_annulation", columnDefinition = "TEXT")
    private String motifAnnulation;

    @Column(name = "annule_par", length = 255)
    private String annulePar;

    @Column(name = "annule_le")
    private LocalDateTime annuleLe;
}
