package com.tmk.vtcmanager.application.domain.chauffeur;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Geolocalisation {

    private Long id;
    private Double latitude;
    private Double longitude;
    private LocalDateTime horodatage;
}