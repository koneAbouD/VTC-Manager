package com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response;

import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.interfaces.rest.chauffeur.dto.response.ChauffeurResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.VehiculeResponse;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

public record OperationFinanciereResponse(
        Long id,
        String reference,
        TypeOperation typeOperation,
        CategorieOperationResponse categorie,
        SousCategorieOperationResponse sousCategorie,
        ChauffeurResponse chauffeur,
        VehiculeResponse vehicule,
        Long partenaireId,
        String partenaireNom,
        BigDecimal montant,
        ModePaiement modePaiement,
        LocalDate dateOperation,
        LocalDate dateReference,
        String commentaire,
        StatutOperation statut,
        DetailMaintenanceResponse detailMaintenance,
        /**
         * Faux pour une écriture qui ne se retouche pas en place : encaissement,
         * dépense issue d'une maintenance, extourne ou écriture extournée. Le
         * client masque alors l'action « Modifier » ; l'annulation reste ouverte.
         */
        boolean modifiable,
        /** Écriture contre-passée par celle-ci : non nul sur une extourne. */
        Long extourneDeId,
        /** Renseignés sur une écriture qui a été extournée. */
        String motifAnnulation,
        String annulePar,
        LocalDateTime annuleLe
) {}
