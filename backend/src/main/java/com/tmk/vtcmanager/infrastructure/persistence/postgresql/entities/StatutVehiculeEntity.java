package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import lombok.*;

@Entity
@Table(name = StatutVehiculeEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class StatutVehiculeEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "statuts_vehicule";

    @Id
    @Column(length = 30)
    private String code;

    @NotBlank
    @Column(nullable = false, length = 100)
    private String libelle;

    private String signification;

    @NotBlank
    @Column(nullable = false, length = 20)
    private String couleur;

    @Column(nullable = false)
    private Integer ordre;
}
