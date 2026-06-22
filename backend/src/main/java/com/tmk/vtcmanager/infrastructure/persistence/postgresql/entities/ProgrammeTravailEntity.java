package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import com.tmk.vtcmanager.application.domain.programmeTravail.JourSemaine;
import com.tmk.vtcmanager.application.domain.programmeTravail.ModeAlternance;
import com.tmk.vtcmanager.application.domain.programmeTravail.TypeProgrammeTravail;
import jakarta.persistence.CascadeType;
import jakarta.persistence.CollectionTable;
import jakarta.persistence.Column;
import jakarta.persistence.ElementCollection;
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
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

@Entity
@Table(name = ProgrammeTravailEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ProgrammeTravailEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "vehicule_programmes";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "vehicule_id", nullable = false, unique = true)
    private VehiculeEntity vehicule;

    @Column(name = "nombre_chauffeurs_autorises", nullable = false)
    private Integer nombreChauffeursAutorises;

    @Enumerated(EnumType.STRING)
    @Column(name = "type_programme", nullable = false, length = 30)
    private TypeProgrammeTravail typeProgramme;

    @Column(name = "heure_debut_service", nullable = false)
    private LocalTime heureDebutService;

    @Column(name = "heure_fin_service", nullable = false)
    private LocalTime heureFinService;

    @Enumerated(EnumType.STRING)
    @Column(name = "mode_alternance", nullable = false, length = 30)
    private ModeAlternance modeAlternance;

    @Column(name = "jours_alternance")
    private Integer joursAlternance;

    @Column(name = "date_debut_alternance")
    private LocalDate dateDebutAlternance;

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(
            name = "vehicule_programme_jours_alternance",
            joinColumns = @JoinColumn(name = "programme_id")
    )
    @Enumerated(EnumType.STRING)
    @Column(name = "jour_semaine", length = 15)
    @Builder.Default
    private Set<JourSemaine> joursAlternanceSemaine = new HashSet<>();

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(
            name = "vehicule_programme_jours_travail",
            joinColumns = @JoinColumn(name = "programme_id")
    )
    @Enumerated(EnumType.STRING)
    @Column(name = "jour_semaine", length = 15)
    @Builder.Default
    private Set<JourSemaine> joursTravailSemaine = new HashSet<>();

    @Column(name = "jour_salaire_actif", nullable = false)
    private boolean jourSalaireActif;

    @Enumerated(EnumType.STRING)
    @Column(name = "jour_salaire", length = 15)
    private JourSemaine jourSalaire;

    @OneToMany(mappedBy = "programme", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<ProgrammeChauffeurEntity> chauffeurs = new ArrayList<>();
}
