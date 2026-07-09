package com.tmk.vtcmanager.interfaces.rest.contravention.dto.response;

/**
 * Bilan renvoyé après confirmation de l'import.
 */
public record ResultatImportResponse(
        int contraventionsCreees,
        int contraventionsRattachees,
        int doublonsIgnores
) {}
