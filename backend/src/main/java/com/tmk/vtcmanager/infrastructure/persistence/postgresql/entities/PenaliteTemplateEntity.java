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
import lombok.ToString;
import lombok.EqualsAndHashCode;

@Entity
@Table(name = PenaliteTemplateEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PenaliteTemplateEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "penalite_template";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String typePenalite;

    private String typeSanction;

    @Column(nullable = true)
    private Integer dureeSanctionSecondes;

    @Column(nullable = true)
    private Double montant;

    @Column(nullable = true)
    private Integer dureeImmobilisationMinutes;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "condition_travail_id", nullable = false)
    @ToString.Exclude
    @EqualsAndHashCode.Exclude
    private ConditionTravailEntity conditionTravail;
}
