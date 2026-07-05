package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import com.tmk.vtcmanager.application.domain.indisponibilite.IndisponibiliteStatut;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;

@Entity
@Table(name = IndisponibiliteVehiculeEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class IndisponibiliteVehiculeEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "indisponibilites_vehicule";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "vehicule_id", nullable = false)
    private VehiculeEntity vehicule;

    @Column(name = "date_debut", nullable = false)
    private LocalDate dateDebut;

    @Column(name = "date_fin")
    private LocalDate dateFin;

    private String motif;

    private String commentaire;

    @Enumerated(EnumType.STRING)
    @Column(length = 30)
    private IndisponibiliteStatut statut;
}
