package com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response;

import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.interfaces.rest.chauffeur.dto.response.ChauffeurResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.VehiculeResponse;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

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
        /**
         * Faux quand la contre-passation serait refusée : écriture qui ne
         * s'annule pas (extourne, écriture déjà extournée ou déjà neutralisée),
         * ou arrêté — période comptable close, caisse comptée — couvrant sa
         * date. Le client masque alors l'action « Annuler » sans avoir à
         * rejouer la règle.
         */
        Boolean annulable,
        /** Écriture contre-passée par celle-ci : non nul sur une extourne. */
        Long extourneDeId,
        /**
         * Versement dont l'écriture fait partie, partagé avec sa sœur du même
         * billet. Le client rassemble sur cette clé, et sur elle seule : le
         * serveur garantit qu'elle désigne encore un seul versement.
         */
        UUID versementId,
        /** Renseignés sur une écriture qui a été extournée. */
        String motifAnnulation,
        String annulePar,
        LocalDateTime annuleLe
) {}
