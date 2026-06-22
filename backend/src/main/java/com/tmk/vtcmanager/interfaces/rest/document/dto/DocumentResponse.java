package com.tmk.vtcmanager.interfaces.rest.document.dto;

import com.tmk.vtcmanager.application.domain.chauffeur.TypePermis;
import com.tmk.vtcmanager.application.domain.document.CibleDocument;
import com.tmk.vtcmanager.application.domain.document.DocumentStatut;

import java.time.LocalDate;
import java.util.Set;

public record DocumentResponse(
        Long id,
        TypeDocumentResponse typeDocument,
        String reference,
        LocalDate dateEmission,
        LocalDate dateExpiration,
        DocumentStatut statut,
        String fichierNom,
        String fichierType,
        String fichierUrl,
        CibleDocument cible,
        Long cibleId,
        LocalDate dateArchivage,
        String archivedBy,
        String raisonArchivage,
        Set<TypePermis> categorie,
        Boolean permanence
) {}
