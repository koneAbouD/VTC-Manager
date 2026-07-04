package com.tmk.vtcmanager.application.domain.tresorerie;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Mouvement entre deux comptes de trésorerie : ni revenu ni dépense,
 * n'apparaît pas au compte de résultat.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TransfertTresorerie {

    private Long id;
    private Long compteSourceId;
    private Long compteDestinationId;
    private BigDecimal montant;
    private LocalDate dateTransfert;
    private String commentaire;
}
