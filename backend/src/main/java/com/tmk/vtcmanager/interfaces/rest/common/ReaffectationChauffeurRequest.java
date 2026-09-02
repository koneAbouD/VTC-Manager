package com.tmk.vtcmanager.interfaces.rest.common;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/**
 * Corps de requête d'un changement de débiteur sur une créance.
 *
 * <p>Le motif est obligatoire au même titre qu'à l'annulation : une créance qui
 * passe d'un compte à un autre doit pouvoir s'expliquer six mois plus tard.
 */
public record ReaffectationChauffeurRequest(
        @NotNull(message = "Le chauffeur est obligatoire.") Long chauffeurId,
        @NotBlank(message = "Le motif de la réaffectation est obligatoire.") String motif
) {}
