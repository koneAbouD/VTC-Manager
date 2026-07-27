package com.tmk.vtcmanager.interfaces.rest.tresorerie.dto.request;

import com.tmk.vtcmanager.application.domain.tresorerie.StatutImputationEcart;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * Décision sur un écart de caisse en attente : PERTE (l'entreprise supporte) ou
 * RECOUVREE (le responsable rembourse).
 */
public record ImputationEcartRequest(
        @NotNull StatutImputationEcart decision,
        @NotBlank @Size(max = 500) String motif
) {}
