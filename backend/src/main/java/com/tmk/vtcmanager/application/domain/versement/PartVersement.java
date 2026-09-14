package com.tmk.vtcmanager.application.domain.versement;

import java.math.BigDecimal;

/** Ce qu'un versement impute à une créance : la ligne, et le montant qui lui revient. */
public record PartVersement(Long ligneId, BigDecimal montant) {}
