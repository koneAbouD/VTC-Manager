package com.tmk.vtcmanager.application.domain.arrete;

import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * Règlement d'un arrêté pour UN bénéficiaire chauffeur (le tiers = une personne).
 * Un arrêté par véhicule multi-chauffeur en produit plusieurs, un par chauffeur.
 *
 * <p>net = fonds cotisation − créances compensées. Si net &gt; 0 il est restitué
 * (décaissement réel) ; si net &le; 0 rien n'est versé. {@code reliquatReporte}
 * porte les créances de la période non compensées, reprises par l'arrêté suivant.</p>
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ReglementArrete {

    private Long id;
    private Long arreteId;
    private Long chauffeurId;
    /** Nom d'affichage du bénéficiaire (transient, non persisté). */
    private String chauffeurNom;
    private BigDecimal totalCotisations;
    private BigDecimal totalCreancesCompensees;
    private BigDecimal montantNet;
    /**
     * Ce qui reste dû, après cet arrêté, sur les créances datées jusqu'à la fin
     * de la période. Les créances postérieures n'en font pas partie : elles
     * relèvent de la période suivante. Repris par l'arrêté suivant dans
     * {@link #reliquatAnterieur}.
     */
    private BigDecimal reliquatReporte;
    /**
     * Ce que le chauffeur devait encore, au moment de l'arrêté, sur ses créances
     * datées avant le début de la période : le reliquat des périodes
     * précédentes. Compris dans les dettes que le fonds éteint en premier.
     */
    private BigDecimal reliquatAnterieur;
    private ModePaiement modePaiement;
    private Long compteTresorerieId;
    private Long operationDecaissementId;

    public boolean aRestitution() {
        return montantNet != null && montantNet.signum() > 0;
    }
}
