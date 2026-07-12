package com.tmk.vtcmanager.application.domain.arrete;

import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * Photo figée d'un document pris en compte dans un arrêté : une cotisation
 * (CREDIT, dépôt) ou une créance recette/pénalité/contravention (DEBIT).
 * Porte chauffeur_id ET vehicule_id → ventilation par l'un ou l'autre axe.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class LigneArrete {

    private Long id;
    private Long arreteId;
    private TypeDocumentCreance document;
    private Long documentId;
    private Long chauffeurId;
    private Long vehiculeId;
    private BigDecimal montant;
    private SensArrete sens;
    /** Opération de compensation créée pour une ligne DEBIT (null pour un CREDIT). Sert au contre-passage. */
    private Long operationId;
}
