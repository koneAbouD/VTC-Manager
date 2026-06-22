package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import com.tmk.vtcmanager.application.domain.groupe.GroupeStatut;
import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import lombok.*;

@Entity
@Table(name = GroupeVehiculeEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class GroupeVehiculeEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "groupes_vehicule";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @NotBlank
    @Column(nullable = false, unique = true)
    private String nom;

    private String description;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "type_activite_id")
    private TypeActiviteEntity typeActivite;

    @Enumerated(EnumType.STRING)
    @Column(length = 20, nullable = false)
    private GroupeStatut statut;

    @OneToOne(mappedBy = "groupe", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    private GestionnaireGroupeEntity gestionnaire;
}