package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;

@Entity
@Table(name = CatalogueElementMaintenanceEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CatalogueElementMaintenanceEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "catalogue_elements_maintenance";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String libelle;

    @Column(nullable = false)
    private boolean actif;

    @Column(name = "montant_defaut", precision = 19, scale = 2)
    private BigDecimal montantDefaut;

    @Column(length = 512)
    private String image;
}
