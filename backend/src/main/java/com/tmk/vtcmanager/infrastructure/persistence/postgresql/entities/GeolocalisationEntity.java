package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = GeolocalisationEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class GeolocalisationEntity {

    public static final String TABLE_NAME = "geolocalisations";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Double latitude;

    @Column(nullable = false)
    private Double longitude;

    @Column(nullable = false)
    private LocalDateTime horodatage;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "chauffeur_id", nullable = false, unique = true)
    private ChauffeurEntity chauffeur;
}