package com.tmk.vtcmanager.interfaces.rest.contravention.dto.response;

import java.util.List;

/**
 * Aperçu d'un relevé PDF importé : véhicule résolu, candidats à réviser et
 * doublons écartés. Rien n'est encore persisté.
 */
public record ApercuImportResponse(
        String plaque,
        Long vehiculeId,
        String vehiculeImmatriculation,
        boolean vehiculeInconnu,
        String documentSourcePath,
        List<ContraventionResponse> candidats,
        List<String> doublonsIgnores
) {}
