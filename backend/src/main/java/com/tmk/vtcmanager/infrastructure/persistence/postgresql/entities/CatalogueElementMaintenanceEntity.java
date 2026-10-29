package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import jakarta.persistence.*;
import lombok.*;

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

    // Unicité portée par l'index uk_catalogue_elements_maintenance_libelle_ci
    // (libellé sans tenir compte de la casse) : un élément sert tous les modèles,
    // ce qui dépend du modèle est dans tarifs_elements_maintenance.
    @Column(nullable = false)
    private String libelle;

    @Column(nullable = false)
    private boolean actif;

    /** Type de maintenance réservé ; null = élément commun à tous les types. */
    @Column(name = "categorie_type_id")
    private Long categorieTypeId;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "categorie_type_id", insertable = false, updatable = false)
    private CategorieOperationEntity categorieType;
}
