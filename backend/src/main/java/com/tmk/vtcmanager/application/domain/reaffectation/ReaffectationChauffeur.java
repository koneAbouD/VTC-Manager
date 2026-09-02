package com.tmk.vtcmanager.application.domain.reaffectation;

import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * Trace d'un changement de tiers sur une créance : la recette ou la cotisation
 * n'a pas bougé d'un franc, mais elle a changé de débiteur.
 *
 * <p>Un fait daté et signé, jamais modifié : se rétracter, c'est réaffecter
 * dans l'autre sens, ce qui écrit une seconde trace. C'est ce qui permet de
 * répondre plus tard à « pourquoi cette recette est-elle au compte de
 * quelqu'un que le programme du jour ne désignait pas ? ».
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ReaffectationChauffeur {

    private Long id;
    /** RECETTE ou COTISATION — les seules créances réaffectables à ce jour. */
    private TypeDocumentCreance document;
    private Long documentId;
    /** Véhicule de la ligne, inchangé par l'opération : consigné pour la lecture. */
    private Long vehiculeId;
    /** Jour que la ligne couvre — c'est lui que les verrous ont éprouvé. */
    private LocalDate dateDocument;
    private Long ancienChauffeurId;
    private Long nouveauChauffeurId;
    /** Obligatoire, comme le motif d'annulation. */
    private String motif;
    /** Écritures d'encaissement passées au nouveau tiers dans la foulée. */
    private int operationsReprises;
    /** Pénalités « recette non versée » basculées avec la ligne. */
    private int penalitesReprises;
    private String createdBy;
    private LocalDateTime createdAt;
}
