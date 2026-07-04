package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatus;
import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatutMotif;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = VehiculeStatutHistoriqueEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class VehiculeStatutHistoriqueEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "vehicule_statut_historique";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "vehicule_id", nullable = false)
    private Long vehiculeId;

    @Enumerated(EnumType.STRING)
    @Column(length = 30, nullable = false)
    private VehiculeStatus statut;

    @Enumerated(EnumType.STRING)
    @Column(length = 40)
    private VehiculeStatutMotif motif;

    @Column(name = "date_debut", nullable = false)
    private LocalDateTime dateDebut;

    @Column(name = "date_fin")
    private LocalDateTime dateFin;
}
