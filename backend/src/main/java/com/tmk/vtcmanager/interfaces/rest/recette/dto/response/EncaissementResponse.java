package com.tmk.vtcmanager.interfaces.rest.recette.dto.response;

import com.tmk.vtcmanager.application.domain.operation.ModePaiement;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

public record EncaissementResponse(
        Long id,
        Long ligneRecetteId,
        Long operationFinanciereId,
        BigDecimal montant,
        ModePaiement modeEncaissement,
        LocalDate dateEncaissement,
        String reference,
        String commentaire,
        /**
         * Renseignés si le versement a été extourné. L'encaissement reste dans
         * la liste — il a eu lieu — mais il ne compte plus dans le montant
         * encaissé de la ligne : le client doit le distinguer des versements
         * qui tiennent toujours.
         */
        LocalDateTime annuleLe,
        String annulePar,
        String motifAnnulation,
        /**
         * Renseignés à la lecture : faux si la date de ce versement ne peut
         * plus être corrigée, et pourquoi. Le client masque alors le geste.
         */
        Boolean dateModifiable,
        String motifDateNonModifiable
) {}
