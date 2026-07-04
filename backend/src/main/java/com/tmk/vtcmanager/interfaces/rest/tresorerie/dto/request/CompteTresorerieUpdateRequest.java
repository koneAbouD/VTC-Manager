package com.tmk.vtcmanager.interfaces.rest.tresorerie.dto.request;

import java.math.BigDecimal;

/** Code et type immuables : les opérations passées y sont rattachées. */
public record CompteTresorerieUpdateRequest(
        String libelle,
        String operateur,
        BigDecimal soldeInitial,
        boolean parDefaut,
        boolean actif
) {}
