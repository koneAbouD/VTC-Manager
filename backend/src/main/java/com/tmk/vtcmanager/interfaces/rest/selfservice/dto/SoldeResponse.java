package com.tmk.vtcmanager.interfaces.rest.selfservice.dto;

import com.tmk.vtcmanager.interfaces.rest.arrete.dto.response.CompteCourantResponse;

/**
 * Soldes du chauffeur connecté : son compte courant (fonds de cotisation vs créances)
 * et, s'il est affecté, le compte courant du véhicule qu'il conduit.
 */
public record SoldeResponse(
        CompteCourantResponse chauffeur,
        CompteCourantResponse vehicule
) {}
