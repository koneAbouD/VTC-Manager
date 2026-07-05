package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import com.tmk.vtcmanager.application.domain.conditionTravail.TypePenalite;
import com.tmk.vtcmanager.application.domain.conditionTravail.TypeSanction;
import com.tmk.vtcmanager.application.domain.penalite.StatutLignePenalite;
import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = LignePenaliteEntity.TABLE_NAME)
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class LignePenaliteEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "lignes_penalite";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "vehicule_id", nullable = false)
    private VehiculeEntity vehicule;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "chauffeur_id", nullable = false)
    private ChauffeurEntity chauffeur;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "penalite_template_id")
    private PenaliteTemplateEntity penaliteTemplate;

    @Enumerated(EnumType.STRING)
    @Column(name = "type_penalite", nullable = false, length = 50)
    private TypePenalite typePenalite;

    @Enumerated(EnumType.STRING)
    @Column(name = "type_sanction", nullable = false, length = 50)
    private TypeSanction typeSanction;

    @Column(name = "montant", precision = 19, scale = 2, nullable = false)
    private BigDecimal montant;

    @Column(name = "montant_encaisse", precision = 19, scale = 2, nullable = false)
    private BigDecimal montantEncaisse;

    @Column(name = "duree_sanction_secondes")
    private Integer dureeSanctionSecondes;

    @Column(name = "duree_immobilisation_minutes")
    private Integer dureeImmobilisationMinutes;

    @Column(name = "date_debut_immobilisation")
    private LocalDateTime dateDebutImmobilisation;

    @Column(name = "date_fin_immobilisation")
    private LocalDateTime dateFinImmobilisation;

    @Column(name = "date_generation", nullable = false)
    private LocalDate dateGeneration;

    @Column(name = "date_faute")
    private LocalDate dateFaute;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "ligne_recette_id")
    private LigneRecetteEntity ligneRecette;

    @Enumerated(EnumType.STRING)
    @Column(name = "statut", nullable = false, length = 30)
    private StatutLignePenalite statut;

    @Column(name = "commentaire")
    private String commentaire;

    @Column(name = "motif_annulation", length = 500)
    private String motifAnnulation;

    @OneToMany(mappedBy = "lignePenalite", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @Builder.Default
    private List<EncaissementPenaliteEntity> encaissements = new ArrayList<>();
}
