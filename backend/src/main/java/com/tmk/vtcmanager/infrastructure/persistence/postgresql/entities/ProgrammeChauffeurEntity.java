package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDate;

@Entity
@Table(name = ProgrammeChauffeurEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ProgrammeChauffeurEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "vehicule_programme_chauffeurs";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "programme_id", nullable = false)
    private ProgrammeTravailEntity programme;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "chauffeur_id", nullable = false)
    private ChauffeurEntity chauffeur;

    @Column(name = "ordre_alternance")
    private Integer ordreAlternance;

    @Column(name = "ordre_jour_salaire")
    private Integer ordreJourSalaire;

    @Column(name = "date_service")
    private LocalDate dateService;
}
