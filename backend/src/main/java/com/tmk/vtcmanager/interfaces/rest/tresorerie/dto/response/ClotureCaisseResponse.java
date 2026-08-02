package com.tmk.vtcmanager.interfaces.rest.tresorerie.dto.response;

import com.tmk.vtcmanager.application.domain.tresorerie.StatutImputationEcart;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

public record ClotureCaisseResponse(
        Long id,
        Long compteId,
        LocalDate dateCloture,
        BigDecimal soldeTheorique,
        BigDecimal soldeCompte,
        BigDecimal ecart,
        String motifEcart,
        Long operationId,
        String responsable,
        /** Null quand il n'y a pas d'écart : rien à imputer. */
        StatutImputationEcart imputationStatut,
        String imputationMotif,
        LocalDateTime imputeeLe,
        String imputeePar,
        Long operationImputationId,
        /** Renseignés quand le relevé a été annulé : il ne fait plus foi. */
        LocalDateTime annuleLe,
        String annulePar,
        String motifAnnulation
) {}
