package com.tmk.vtcmanager.interfaces.rest.cotisation.dto.response;

import com.tmk.vtcmanager.application.domain.operation.ModePaiement;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

public record EncaissementCotisationResponse(
        Long id,
        Long ligneCotisationId,
        Long operationFinanciereId,
        BigDecimal montant,
        ModePaiement modeEncaissement,
        LocalDate dateEncaissement,
        String reference,
        String commentaire,
        /** Renseignés si le versement a été extourné : il ne compte plus. */
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
