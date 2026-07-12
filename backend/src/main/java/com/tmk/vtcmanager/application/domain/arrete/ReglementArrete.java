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
 * (décaissement réel) ; si net &le; 0 rien n'est versé et {@code reliquatReporte}
 * porte les créances non compensées qui restent ouvertes.</p>
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
    private BigDecimal reliquatReporte;
    private ModePaiement modePaiement;
    private Long compteTresorerieId;
    private Long operationDecaissementId;

    public boolean aRestitution() {
        return montantNet != null && montantNet.signum() > 0;
    }
}
