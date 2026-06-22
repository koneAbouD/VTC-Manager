package com.tmk.vtcmanager.application.domain.operation;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ElementMaintenance {

    private Long id;
    private CatalogueElementMaintenance catalogueElement; // null si entrée libre
    private String libelle;                               // null si catalogue utilisé
    private BigDecimal montant;

    /** Retourne le libellé effectif quelle que soit l'origine. */
    public String getEffectiveLibelle() {
        return catalogueElement != null ? catalogueElement.getLibelle() : libelle;
    }
}
