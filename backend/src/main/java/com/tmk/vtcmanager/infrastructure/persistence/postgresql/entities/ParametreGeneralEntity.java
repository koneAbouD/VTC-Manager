package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = ParametreGeneralEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ParametreGeneralEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "parametres_generaux";

    @Id
    private String cle;

    @Column(nullable = false)
    private String valeur;

    @Column(nullable = false)
    private String libelle;

    private String description;
}
