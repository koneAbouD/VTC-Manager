package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = CloturePeriodeEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CloturePeriodeEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "clotures_periode";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private int annee;

    @Column(nullable = false)
    private int mois;

    @Column(name = "date_cloture", nullable = false)
    private LocalDateTime dateCloture;
}
