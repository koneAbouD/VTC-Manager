package com.tmk.vtcmanager.application.domain.modification;

import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import lombok.Builder;

import java.math.BigDecimal;

/**
 * Trace d'une correction du montant dû d'une créance — recette attendue ou
 * amende. La ligne ne garde que la nouvelle valeur : c'est ici que se lit
 * l'ancienne, avec qui l'a changée et pourquoi.
 */
@Builder
public record ModificationMontant(
        TypeDocumentCreance document,
        Long documentId,
        BigDecimal ancienMontant,
        BigDecimal nouveauMontant,
        String motif,
        String createdBy
) {}
