package com.tmk.vtcmanager.interfaces.rest.maintenance.dto.response;

import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response.CategorieOperationResponse;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response.DetailMaintenanceResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.VehiculeResponse;

import java.math.BigDecimal;
import java.time.LocalDate;

public record MaintenanceResponse(
        Long id,
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
        VehiculeResponse vehicule,
        CategorieOperationResponse categorieType,
        DetailMaintenanceResponse detailMaintenance
) {}