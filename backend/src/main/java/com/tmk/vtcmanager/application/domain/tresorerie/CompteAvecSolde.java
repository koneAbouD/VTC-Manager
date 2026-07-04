package com.tmk.vtcmanager.application.domain.tresorerie;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CompteAvecSolde {

    private CompteTresorerie compte;
    private BigDecimal solde;
}
