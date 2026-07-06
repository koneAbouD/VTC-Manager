package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatus;
import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import lombok.*;

import java.time.LocalDate;

@Entity
@Table(name = VehiculeEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class VehiculeEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "vehicules";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @NotBlank
    @Column(unique = true, nullable = false)
    private String immatriculation;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "type_activite_id")
    private TypeActiviteEntity activite;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "groupe_id")
    private GroupeVehiculeEntity groupe;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "condition_travail_id")
    private ConditionTravailEntity conditionTravail;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "type_vehicule_id")
    private TypeVehiculeEntity type;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "marque_id", nullable = false)
    private MarqueEntity marque;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "modele_id", nullable = false)
    private ModeleEntity modele;

    @Column(name = "numero_chassis", length = 50)
    private String numeroChassis;

    @Column(name = "numero_telephone_balise", length = 30)
    private String numeroTelephoneBalise;

    @Column(name = "identifiant_balise", length = 100)
    private String identifiantBalise;

    private String couleur;
    private Integer kilometrage;

    @Enumerated(EnumType.STRING)
    @Column(length = 30)
    private VehiculeStatus statut;

    @Enumerated(EnumType.STRING)
    @Column(name = "statut_manuel", length = 30)
    private VehiculeStatus statutManuel;

    @Column(name = "date_achat")
    private LocalDate dateAchat;

    @Column(name = "prix_achat", precision = 19, scale = 2)
    private java.math.BigDecimal prixAchat;

    /** Durée d'amortissement linéaire (60 mois par défaut). */
    @Builder.Default
    @Column(name = "duree_amortissement_mois", nullable = false)
    private int dureeAmortissementMois = 60;

    @Column(name = "date_prochaine_maintenance")
    private LocalDate dateProchaineMaintenance;

    @Column(name = "date_mise_en_circulation")
    private LocalDate dateMiseEnCirculation;

    @Column(name = "date_entree_flotte")
    private LocalDate dateEntreeFlotte;
}
