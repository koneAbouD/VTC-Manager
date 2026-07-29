package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import com.tmk.vtcmanager.application.domain.fournisseur.StatutFactureFournisseur;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = FactureFournisseurEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FactureFournisseurEntity extends AbstractEcritureAuditEntity {

    public static final String TABLE_NAME = "factures_fournisseur";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 30)
    private String reference;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "fournisseur_id", nullable = false)
    private FournisseurEntity fournisseur;

    @Column(name = "numero_piece", length = 100)
    private String numeroPiece;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "categorie_id")
    private CategorieOperationEntity categorie;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "vehicule_id")
    private VehiculeEntity vehicule;

    @Column(name = "date_facture", nullable = false)
    private LocalDate dateFacture;

    @Column(name = "date_echeance", nullable = false)
    private LocalDate dateEcheance;

    @Column(nullable = false, precision = 19, scale = 2)
    private BigDecimal montant;

    @Builder.Default
    @Column(name = "montant_paye", nullable = false, precision = 19, scale = 2)
    private BigDecimal montantPaye = BigDecimal.ZERO;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 25)
    private StatutFactureFournisseur statut;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "motif_annulation", columnDefinition = "TEXT")
    private String motifAnnulation;

    @Column(name = "annule_le")
    private LocalDateTime annuleLe;

    @Column(name = "annule_par", length = 255)
    private String annulePar;
}
