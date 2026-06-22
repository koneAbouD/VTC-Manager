package com.tmk.vtcmanager.application.domain.conditionTravail;

import lombok.Data;

import java.math.BigDecimal;

@Data
public class CotisationTemplate {
    Long id;
    String nom;
    BigDecimal montant;
}
