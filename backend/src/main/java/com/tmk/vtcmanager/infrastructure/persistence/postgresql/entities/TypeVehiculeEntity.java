package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import lombok.*;
import org.hibernate.annotations.ColumnDefault;

@Entity
@Table(name = TypeVehiculeEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TypeVehiculeEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "types_vehicule";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @NotBlank
    @Column(nullable = false, unique = true)
    private String nom;

    private String description;

    @Builder.Default
    @Column(nullable = false)
    @ColumnDefault("true")
    private Boolean actif = true;
}
