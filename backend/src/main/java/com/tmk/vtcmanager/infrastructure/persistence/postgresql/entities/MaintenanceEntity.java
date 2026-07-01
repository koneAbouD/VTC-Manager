package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;

@Entity
@Table(name = MaintenanceEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MaintenanceEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "maintenances";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(length = 40)
    private String type;

    @Column(name = "date_prevue")
    private LocalDate datePrevue;

    @Column(name = "date_effectuee")
    private LocalDate dateEffectuee;

    @Column(name = "duree_heures")
    private Integer dureeHeures;

    private String description;

    @Column(name = "kilometrage_au_moment")
    private Integer kilometrageAuMoment;

    @Column(name = "kilometrage_prochaine")
    private Integer kilometrageProchaine;

    @Column(precision = 19, scale = 2)
    private BigDecimal cout;

    private String prestataire;

    @Enumerated(EnumType.STRING)
    @Column(length = 30)
    private MaintenanceStatus statut;

    /** Statut d'avant complétion, pour restaurer la maintenance à l'annulation. */
    @Enumerated(EnumType.STRING)
    @Column(name = "statut_avant_completion", length = 30)
    private MaintenanceStatus statutAvantCompletion;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "vehicule_id")
    private VehiculeEntity vehicule;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "categorie_type_id")
    private CategorieOperationEntity categorieType;

    @OneToOne(cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @JoinColumn(name = "detail_maintenance_id")
    private DetailMaintenanceEntity detailMaintenance;
}
