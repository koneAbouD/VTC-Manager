package com.tmk.vtcmanager.application.domain.finance;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Document ouvert d'un tiers (projection de la vue v_creances_chauffeurs).
 * document + documentId permettent au mobile de rouvrir le flux
 * d'encaissement du module d'origine.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class LigneCreance {

    private TypeDocumentCreance document;
    private Long documentId;
    private Long vehiculeId;
    /** Chauffeur débiteur (utile dans le détail par véhicule). */
    private Long chauffeurId;
    private String chauffeurNom;
    private LocalDate dateReference;
    private BigDecimal montantDu;
    private BigDecimal montantRegle;
    private BigDecimal restant;
}
