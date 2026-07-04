package com.tmk.vtcmanager.interfaces.rest.tresorerie.dto.response;

import com.tmk.vtcmanager.application.domain.tresorerie.TypeCompteTresorerie;

import java.math.BigDecimal;

public record CompteTresorerieResponse(
        Long id,
        String code,
        String libelle,
        TypeCompteTresorerie type,
        String operateur,
        BigDecimal soldeInitial,
        boolean parDefaut,
        boolean actif,
        BigDecimal solde
) {}
