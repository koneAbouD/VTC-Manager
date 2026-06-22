package com.tmk.vtcmanager.interfaces.rest.maintenance.dto.request;

import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request.DetailMaintenanceRequest;
import jakarta.validation.Valid;

import java.math.BigDecimal;
import java.time.LocalDate;

public record MaintenanceRequest(
        String type,
        LocalDate datePrevue,
        LocalDate dateEffectuee,
        Integer dureeHeures,
        String description,
        Integer kilometrageAuMoment,
        Integer kilometrageProchaine,
        BigDecimal cout,
        String prestataire,
        MaintenanceStatus statut,
        Long vehiculeId,
        Long categorieTypeId,
        @Valid DetailMaintenanceRequest detailMaintenance
) {}