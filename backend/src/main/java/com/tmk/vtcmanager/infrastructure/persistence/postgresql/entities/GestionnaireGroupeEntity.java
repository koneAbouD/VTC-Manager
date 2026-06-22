package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import lombok.*;

import java.time.LocalDate;

@Entity
@Table(
    name = GestionnaireGroupeEntity.TABLE_NAME,
    uniqueConstraints = @UniqueConstraint(name = "uk_gestionnaire_groupe_user", columnNames = {"groupe_id", "user_id"})
)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class GestionnaireGroupeEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "gestionnaires_groupe";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "groupe_id", nullable = false)
    private GroupeVehiculeEntity groupe;

    @NotBlank
    @Column(name = "user_id", nullable = false)
    private String userId;

    @Column(name = "date_debut")
    private LocalDate dateDebut;

    @Column(name = "date_fin")
    private LocalDate dateFin;
}