package com.tmk.vtcmanager.application.domain.configurationRecette;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CotisationRecette {

    private Long id;
    private String nom;
    private BigDecimal montant;
    private Integer ordre;

    public void normalize(int defaultOrder) {
        if (nom != null) {
            nom = nom.trim();
        }
        ordre = defaultOrder;
    }

    public void validate() {
        if (nom == null || nom.isBlank()) {
            throw new IllegalArgumentException("Le nom de la cotisation est obligatoire.");
        }
        if (montant == null || montant.signum() <= 0) {
            throw new IllegalArgumentException("Le montant de la cotisation doit être strictement positif.");
        }
        if (ordre == null || ordre < 1) {
            throw new IllegalArgumentException("L'ordre des cotisations est invalide.");
        }
    }
}
