package com.tmk.vtcmanager.application.domain.indisponibilite;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Trace une assignation de programme (vehicule_programme_chauffeurs) impactée
 * par une indisponibilité, pour pouvoir rétablir le titulaire à la fin.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class IndisponibiliteRemplacement {
    private Long id;
    private Long indisponibiliteId;
    private Long programmeChauffeurId;
    private Long chauffeurTitulaireId;
}
