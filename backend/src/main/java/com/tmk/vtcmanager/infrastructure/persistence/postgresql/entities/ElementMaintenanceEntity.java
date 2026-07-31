package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;

@Entity
@Table(name = ElementMaintenanceEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ElementMaintenanceEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "elements_maintenance";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "catalogue_element_id")
    private CatalogueElementMaintenanceEntity catalogueElement;

    @Column(nullable = true)
    private String libelle;

    /** Exemplaires posés. Toujours ≥ 1 (contrainte en base). */
    @Column(nullable = false)
    @Builder.Default
    private Integer quantite = 1;

    /** Total de la ligne : quantité × prix unitaire. */
    @Column(nullable = false, precision = 19, scale = 2)
    private BigDecimal montant;

    /** Fournisseur de la ligne ; null = celui de l'intervention. */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "partenaire_id")
    private PartenaireEntity partenaire;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "detail_maintenance_id", nullable = false)
    private DetailMaintenanceEntity detailMaintenance;
}
