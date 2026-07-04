package com.tmk.vtcmanager.application.domain.tresorerie;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Clôture de caisse : comparaison du solde théorique et du comptage
 * physique à une date. L'écart éventuel donne lieu à une opération
 * d'ajustement (operationId) qui réaligne le solde sur le comptage.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ClotureCaisse {

    private Long id;
    private Long compteId;
    private LocalDate dateCloture;
    private BigDecimal soldeTheorique;
    /** Montant réellement compté. */
    private BigDecimal soldeCompte;
    /** soldeCompte − soldeTheorique : négatif = manquant. */
    private BigDecimal ecart;
    private String motifEcart;
    private Long operationId;
}
