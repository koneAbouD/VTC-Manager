package com.tmk.vtcmanager.interfaces.rest.finance.dto.response;

import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;

import java.math.BigDecimal;
import java.time.LocalDate;

public record LigneCreanceResponse(
        TypeDocumentCreance document,
        Long documentId,
        Long vehiculeId,
        Long chauffeurId,
        String chauffeurNom,
        LocalDate dateReference,
        BigDecimal montantDu,
        BigDecimal montantRegle,
        BigDecimal restant
) {}
