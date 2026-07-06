package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;

@Entity
@Table(name = VidangeEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class VidangeEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "vidanges";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "vehicule_id", nullable = false)
    private Long vehiculeId;

    @Column(name = "date_vidange", nullable = false)
    private LocalDate dateVidange;

    @Column(name = "kilometrage_vidange", nullable = false)
    private Integer kilometrageVidange;

    @Column(name = "date_prochaine_vidange")
    private LocalDate dateProchaineVidange;

    @Column(name = "kilometrage_prochaine_vidange")
    private Integer kilometrageProchaineVidange;

    @Column(length = 500)
    private String commentaire;
}
