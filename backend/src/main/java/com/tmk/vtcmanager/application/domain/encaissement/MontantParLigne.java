package com.tmk.vtcmanager.application.domain.encaissement;

import java.math.BigDecimal;

/**
 * Une ligne d'un encaissement de masse : ce que le guichet impute à cette
 * créance-là. Le montant est saisi ligne par ligne — un chauffeur solde
 * rarement toutes ses journées au franc près.
 */
public record MontantParLigne(Long ligneId, BigDecimal montant) {}
