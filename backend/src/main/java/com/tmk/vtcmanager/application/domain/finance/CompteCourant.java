package com.tmk.vtcmanager.application.domain.finance;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * Solde de compte courant d'un tiers (chauffeur ou véhicule) : le fonds de
 * cotisation restituable face aux créances ouvertes, ventilées par antériorité.
 * net = fonds − total créances ; sens dérivé (CREDITEUR = en faveur du chauffeur).
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CompteCourant {

    /** Chauffeur ou véhicule selon l'axe interrogé. */
    private Long tiersId;
    private String libelle;
    private BigDecimal fondsCotisation;
    private BigDecimal du0a7Jours;
    private BigDecimal du8a30Jours;
    private BigDecimal duPlus30Jours;
    private BigDecimal totalCreances;
    private BigDecimal net;

    /** true si le net est en faveur du chauffeur (restitution possible). */
    public boolean estCrediteur() {
        return net != null && net.signum() > 0;
    }
}
