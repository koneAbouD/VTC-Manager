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

    // Unicité portée par l'index uk_catalogue_elements_maintenance_libelle_vehicule
    // (libellé, marque, modèle) : un même libellé peut exister par modèle.
    @Column(nullable = false)
    private String libelle;

    @Column(nullable = false)
    private boolean actif;

    @Column(name = "montant_defaut", precision = 19, scale = 2)
    private BigDecimal montantDefaut;

    @Column(length = 512)
    private String image;

    /** Écrits par identifiant ; les associations ci-dessous ne servent qu'à lire les noms. */
    @Column(name = "marque_id")
    private Long marqueId;

    @Column(name = "modele_id")
    private Long modeleId;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "marque_id", insertable = false, updatable = false)
    private MarqueEntity marque;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "modele_id", insertable = false, updatable = false)
    private ModeleEntity modele;
}
