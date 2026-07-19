package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import lombok.*;
import org.hibernate.annotations.ColumnDefault;

@Entity
@Table(
    name = MarqueEntity.TABLE_NAME,
    uniqueConstraints = @UniqueConstraint(name = "uk_marques_nom_type", columnNames = {"nom", "type_id"})
)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MarqueEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "marques";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @NotBlank
    @Column(nullable = false)
    private String nom;
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "type_id", nullable = false)
    private TypeVehiculeEntity type;
    private String paysOrigine;

    @Builder.Default
    @Column(nullable = false)
    @ColumnDefault("true")
    private Boolean actif = true;
}
