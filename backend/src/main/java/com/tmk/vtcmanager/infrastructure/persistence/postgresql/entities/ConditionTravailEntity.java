package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import jakarta.persistence.CascadeType;
import jakarta.persistence.CollectionTable;
import jakarta.persistence.Column;
import jakarta.persistence.ElementCollection;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToMany;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = ConditionTravailEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ConditionTravailEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "condition_travail";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String nom;

    private int nbChauffeurs;

    private String typeProgramme;

    @Column(nullable = false)
    private String heureDebutService;

    @Column(nullable = false)
    private String heureFinService;

    // Null si nbChauffeurs == 1
    private String modeAlternance;

    // Null si nbChauffeurs == 1 ou modeAlternance == MANUELLE
    private Integer joursAlternance;

    private LocalDate dateDebutAlternance;

    // Null si jourSalaire désactivé
    private String jourSalaire;

    @Column(precision = 15, scale = 2, nullable = false)
    private BigDecimal objectifRecette;

    // MONTANT_FIXE | MONTANT_REEL
    @Column(nullable = false)
    private String typeRecette;

    // Null si typeRecette == MONTANT_REEL
    @Column(precision = 15, scale = 2)
    private BigDecimal montantJourSalaire;

    // Prise en compte des jours fériés
    @Column(name = "feries_consideres", nullable = false)
    private boolean feriesConsideres;

    // Recette due le jour férié (recette fixe) ; null = aucune
    @Column(name = "montant_jour_ferie", precision = 15, scale = 2)
    private BigDecimal montantJourFerie;

    // MOBILE_MONEY | ESPECE | VIREMENT
    @Column(nullable = false)
    private String modeEncaissement;

    // JOURNALIER | HEBDOMADAIRE
    @Column(nullable = false)
    private String frequenceVersement;

    // Null si frequenceVersement != HEBDOMADAIRE
    private String jourVersement;

    @Column(nullable = false)
    private String heureVersement;

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "condition_travail_jours", joinColumns = @JoinColumn(name = "condition_id"))
    @Column(name = "jour", length = 15)
    @Builder.Default
    private List<String> joursTravail = new ArrayList<>();

    @OneToMany(mappedBy = "conditionTravail", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.EAGER)
    @Builder.Default
    private List<CotisationTemplateEntity> cotisations = new ArrayList<>();

    @OneToMany(mappedBy = "conditionTravail", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.EAGER)
    @Builder.Default
    private List<PenaliteTemplateEntity> penalites = new ArrayList<>();
}
