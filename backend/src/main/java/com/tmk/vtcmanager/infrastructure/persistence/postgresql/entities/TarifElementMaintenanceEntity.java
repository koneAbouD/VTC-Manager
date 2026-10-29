package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;

/** Un élément du catalogue de maintenance pour un modèle : prix, image, activation. */
@Entity
@Table(name = TarifElementMaintenanceEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TarifElementMaintenanceEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "tarifs_elements_maintenance";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** Écrits par identifiant ; l'association ci-dessous ne sert qu'à lire les noms. */
    @Column(name = "catalogue_element_id", nullable = false)
    private Long elementId;

    @Column(name = "modele_id", nullable = false)
    private Long modeleId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "modele_id", insertable = false, updatable = false)
    private ModeleEntity modele;

    @Column(precision = 19, scale = 2)
    private BigDecimal prix;

    @Column(length = 512)
    private String image;

    @Column(nullable = false)
    private boolean actif;
}
