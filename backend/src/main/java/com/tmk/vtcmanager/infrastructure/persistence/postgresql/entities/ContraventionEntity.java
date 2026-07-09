package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import com.tmk.vtcmanager.application.domain.contravention.ContraventionStatus;
import com.tmk.vtcmanager.application.domain.contravention.StatutRattachement;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;

@Entity
@Table(name = ContraventionEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ContraventionEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "contraventions";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "date_infraction", nullable = false)
    private LocalDate dateInfraction;

    @Column(name = "type_infraction")
    private String typeInfraction;

    private String lieu;

    private String description;

    @Column(precision = 19, scale = 2)
    private BigDecimal montant;

    @Column(name = "numero_contravention", length = 50, unique = true)
    private String numeroContravention;

    @Column(name = "heure_infraction")
    private LocalTime heureInfraction;

    @Column(name = "vitesse_relevee")
    private Integer vitesseRelevee;

    @Column(name = "code_infraction", length = 20)
    private String codeInfraction;

    @Column(name = "document_source_path", length = 512)
    private String documentSourcePath;

    @Enumerated(EnumType.STRING)
    @Column(name = "statut_rattachement", length = 20)
    private StatutRattachement statutRattachement;

    @Column(precision = 19, scale = 2)
    private BigDecimal cotisation;

    @Column(name = "montant_paye", precision = 19, scale = 2)
    private BigDecimal montantPaye;

    @Enumerated(EnumType.STRING)
    @Column(length = 30)
    private ContraventionStatus statut;

    @Column(name = "date_paiement")
    private LocalDate datePaiement;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "chauffeur_id")
    private ChauffeurEntity chauffeur;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "vehicule_id")
    private VehiculeEntity vehicule;
}
