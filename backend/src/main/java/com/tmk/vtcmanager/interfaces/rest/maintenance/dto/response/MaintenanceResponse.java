package com.tmk.vtcmanager.interfaces.rest.maintenance.dto.response;

import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response.CategorieOperationResponse;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response.DetailMaintenanceResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.VehiculeResponse;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

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
        Long partenaireId,
        String partenaireNom,
        MaintenanceStatus statut,
        VehiculeResponse vehicule,
        CategorieOperationResponse categorieType,
        DetailMaintenanceResponse detailMaintenance,
        /** Pourquoi l'intervention a été annulée ; nul tant qu'elle est au programme. */
        String motifAnnulation,
        String annulePar,
        LocalDateTime annuleLe,
        /**
         * Faux si un arrêté — période comptable close, caisse comptée — interdit
         * désormais de restaurer cet élément annulé. Le client masque alors
         * l'action « Restaurer », qui n'aboutirait pas.
         */
        Boolean restaurable
) {}