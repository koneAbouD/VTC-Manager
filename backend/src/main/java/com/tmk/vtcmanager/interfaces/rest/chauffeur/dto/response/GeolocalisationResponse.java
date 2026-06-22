package com.tmk.vtcmanager.interfaces.rest.chauffeur.dto.response;

import java.time.LocalDateTime;

public record GeolocalisationResponse(
        Long id,
        Double latitude,
        Double longitude,
        LocalDateTime horodatage
) {}