package com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;

@Schema(description = "Reprise, pour un modèle, des éléments de maintenance d'un autre modèle.")
public record CopieTarifsRequest(
        @NotNull Long deModeleId,
        @NotNull Long versModeleId,
        @Schema(description = "Reprendre aussi les prix. Absent : oui.", nullable = true)
        Boolean avecPrix,
        @Schema(description = "Reprendre aussi les images. Absent : oui.", nullable = true)
        Boolean avecImages
) {}
