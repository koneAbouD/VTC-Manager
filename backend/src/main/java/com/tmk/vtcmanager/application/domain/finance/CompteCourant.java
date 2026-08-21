package com.tmk.vtcmanager.application.domain.finance;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * Solde de compte courant d'un tiers (chauffeur ou véhicule) : le fonds de
 * cotisation restituable face aux créances ouvertes, ventilées par antériorité.
 *
 * <p>La compensation se joue toujours <b>par chauffeur</b> : le dépôt de l'un ne
 * peut pas éteindre la dette d'un autre. Sur l'axe véhicule, où plusieurs
 * chauffeurs se croisent, un seul solde signé mentirait donc — il netterait
 * entre des personnes différentes. D'où deux montants distincts, calculés à la
 * maille chauffeur puis additionnés : {@link #net} est ce qu'un arrêté verserait
 * réellement, {@link #resteDu} ce qui resterait à la charge des chauffeurs. Sur
 * l'axe chauffeur, la maille étant déjà la bonne, l'un des deux est toujours nul.
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
    /** Montant réellement restituable : Σ max(fonds − créances, 0) par chauffeur. */
    private BigDecimal net;
    /** Ce qui resterait dû après compensation : Σ max(créances − fonds, 0) par chauffeur. */
    private BigDecimal resteDu;

    /** true si le net est en faveur du chauffeur (restitution possible). */
    public boolean estCrediteur() {
        return net != null && net.signum() > 0;
    }

    /**
     * Solde signé pour les écrans qui n'affichent qu'un nombre : le restituable
     * s'il existe, sinon le reste dû en négatif. Ne jamais l'additionner d'un
     * tiers à l'autre — c'est {@link #net} et {@link #resteDu} qui se cumulent.
     */
    public BigDecimal soldeSigne() {
        BigDecimal restituable = net != null ? net : BigDecimal.ZERO;
        if (restituable.signum() > 0) return restituable;
        return resteDu != null ? resteDu.negate() : BigDecimal.ZERO;
    }
}
