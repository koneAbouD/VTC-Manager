package com.tmk.vtcmanager.application.domain.arrete;

import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Créance que l'arrêté laisse ouverte, datée jusqu'à la fin de sa période : le
 * détail du reste dû reporté sur l'arrêté suivant. Constatée, pas compensée —
 * elle ne s'annule pas avec l'arrêté et ne fige pas le débiteur du document.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DetteRestanteArrete {

    private Long id;
    private Long arreteId;
    private TypeDocumentCreance document;
    private Long documentId;
    /** Débiteur ; null pour une dette du véhicule sans chauffeur rattaché. */
    private Long chauffeurId;
    private Long vehiculeId;
    /** Ce que le document réclamait à l'origine. */
    private BigDecimal montantDu;
    /** Ce qu'il doit encore une fois l'arrêté passé. */
    private BigDecimal reste;
    /** Nom du débiteur (résolu à la lecture). */
    private String chauffeurNom;
    /** Immatriculation du véhicule (résolue à la lecture). */
    private String immatriculation;
    /** Jour couvert par le document (résolu à la lecture, ou à l'aperçu). */
    private LocalDate dateDocument;
}
