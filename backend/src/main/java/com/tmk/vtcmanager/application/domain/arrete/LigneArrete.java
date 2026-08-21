package com.tmk.vtcmanager.application.domain.arrete;

import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Photo figée d'un document pris en compte dans un arrêté : une cotisation
 * (CREDIT, dépôt) ou une créance recette/pénalité/contravention (DEBIT).
 * Porte chauffeur_id ET vehicule_id → ventilation par l'un ou l'autre axe.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class LigneArrete {

    private Long id;
    private Long arreteId;
    private TypeDocumentCreance document;
    private Long documentId;
    private Long chauffeurId;
    private Long vehiculeId;
    private BigDecimal montant;
    private SensArrete sens;
    /** Opération de compensation créée pour une ligne DEBIT (null pour un CREDIT). Sert au contre-passage. */
    private Long operationId;
    /** Immatriculation du véhicule de la ligne (résolue à la lecture ; null si non rattachée). */
    private String immatriculation;
    /**
     * Jour que le document couvre — date de recette, de cotisation, de faute ou
     * d'infraction. C'est ce que l'utilisateur reconnaît d'une ligne, là où son
     * identifiant technique ne lui dit rien. Résolue à la lecture depuis le
     * document d'origine, comme l'immatriculation : rien n'est figé au snapshot,
     * et la valeur reste nulle si le document a disparu.
     */
    private LocalDate dateDocument;
    /**
     * Ce que le document doit encore, indépendamment de la part que cet arrêté
     * en éteint. Renseigné à l'aperçu seulement : sans lui, une recette de
     * 10 000 couverte à 3 000 s'affiche « 3 000 » et laisse croire qu'elle est
     * soldée. Null sur un arrêté enregistré — le snapshot fige ce qui a été
     * fait, pas ce qui restait.
     */
    private BigDecimal restant;
}
