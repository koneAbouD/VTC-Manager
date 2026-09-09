package com.tmk.vtcmanager.interfaces.rest.penalite.dto.response;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

public record EncaissementPenaliteResponse(
        Long id,
        Long lignePenaliteId,
        Long operationFinanciereId,
        BigDecimal montant,
        String modeEncaissement,
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
