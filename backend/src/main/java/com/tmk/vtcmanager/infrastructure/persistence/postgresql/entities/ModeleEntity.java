package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import lombok.*;

@Entity
@Table(
    name = ModeleEntity.TABLE_NAME,
    uniqueConstraints = @UniqueConstraint(name = "uk_modeles_nom_type_marque", columnNames = {"nom", "type_id", "marque_id"})
)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ModeleEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "modeles";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @NotBlank
    @Column(nullable = false)
    private String nom;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "type_id", nullable = false)
    private TypeVehiculeEntity type;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "marque_id", nullable = false)
    private MarqueEntity marque;

    @Column(nullable = false)
    private boolean actif;
}
