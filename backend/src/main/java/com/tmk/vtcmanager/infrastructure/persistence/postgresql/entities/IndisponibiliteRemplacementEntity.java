package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = IndisponibiliteRemplacementEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class IndisponibiliteRemplacementEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "indisponibilite_remplacements";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "indisponibilite_id", nullable = false)
    private Long indisponibiliteId;

    @Column(name = "programme_chauffeur_id", nullable = false)
    private Long programmeChauffeurId;

    @Column(name = "chauffeur_titulaire_id", nullable = false)
    private Long chauffeurTitulaireId;
}
