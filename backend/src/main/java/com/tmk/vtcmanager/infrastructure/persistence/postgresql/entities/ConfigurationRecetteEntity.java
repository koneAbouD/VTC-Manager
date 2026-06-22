package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import com.tmk.vtcmanager.application.domain.configurationRecette.FrequenceVersement;
import com.tmk.vtcmanager.application.domain.configurationRecette.ModeEncaissement;
import com.tmk.vtcmanager.application.domain.configurationRecette.TypeRecetteConfiguration;
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
import jakarta.persistence.OneToMany;
import jakarta.persistence.OneToOne;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = ConfigurationRecetteEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ConfigurationRecetteEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "vehicule_configurations_recette";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "vehicule_id", nullable = false, unique = true)
    private VehiculeEntity vehicule;

    @Enumerated(EnumType.STRING)
    @Column(name = "mode_encaissement", nullable = false, length = 30)
    private ModeEncaissement modeEncaissement;

    @Enumerated(EnumType.STRING)
    @Column(name = "type_recette", nullable = false, length = 30)
    private TypeRecetteConfiguration typeRecette;

    @Enumerated(EnumType.STRING)
    @Column(name = "frequence_versement", nullable = false, length = 30)
    private FrequenceVersement frequenceVersement;

    @Column(name = "heure_limite_versement", nullable = false)
    private LocalTime heureLimiteVersement;

    @Column(name = "montant_objectif_par_chauffeur", precision = 19, scale = 2)
    private BigDecimal montantObjectifParChauffeur;

    @Column(name = "montant_jour_salaire", precision = 19, scale = 2)
    private BigDecimal montantJourSalaire;

    @OneToMany(mappedBy = "configuration", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("ordre ASC")
    @Builder.Default
    private List<CotisationRecetteEntity> cotisations = new ArrayList<>();
}
