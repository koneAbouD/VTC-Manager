package com.tmk.vtcmanager.application.domain.operation;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.List;
import java.util.Objects;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DetailMaintenance {

    private Long id;
    private List<ElementMaintenance> elements;

    /** Somme des montants des éléments (0 si aucun élément). */
    public BigDecimal montantTotal() {
        if (elements == null) return BigDecimal.ZERO;
        return elements.stream()
                .map(ElementMaintenance::getMontant)
                .filter(Objects::nonNull)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }
}
