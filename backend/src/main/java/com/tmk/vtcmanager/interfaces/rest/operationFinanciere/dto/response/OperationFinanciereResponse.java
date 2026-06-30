package com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response;

import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.interfaces.rest.chauffeur.dto.response.ChauffeurResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.VehiculeResponse;

import java.math.BigDecimal;
import java.time.LocalDate;

public record OperationFinanciereResponse(
        Long id,
        String reference,
        TypeOperation typeOperation,
        CategorieOperationResponse categorie,
        SousCategorieOperationResponse sousCategorie,
        ChauffeurResponse chauffeur,
        VehiculeResponse vehicule,
        BigDecimal montant,
        ModePaiement modePaiement,
        LocalDate dateOperation,
        LocalDate dateReference,
        String commentaire,
        StatutOperation statut,
        DetailMaintenanceResponse detailMaintenance
) {}
