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

    @Column(nullable = false, precision = 19, scale = 2)
    private BigDecimal montant;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "detail_maintenance_id", nullable = false)
    private DetailMaintenanceEntity detailMaintenance;
}
