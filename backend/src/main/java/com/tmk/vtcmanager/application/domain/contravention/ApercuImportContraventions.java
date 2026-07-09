package com.tmk.vtcmanager.application.domain.contravention;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.ArrayList;
import java.util.List;

/**
 * Résultat de la prévisualisation d'un relevé PDF, avant persistance. Le PDF est
 * déjà archivé (clé {@link #documentSourcePath}) ; les candidats ne sont pas
 * encore enregistrés — l'exploitant les révise puis confirme.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ApercuImportContraventions {

    private String plaque;
    private Long vehiculeId;
    private String vehiculeImmatriculation;

    /** Vrai si la plaque du relevé ne correspond à aucun véhicule connu. */
    private boolean vehiculeInconnu;

    /** Clé de l'objet PDF archivé dans MinIO (à renvoyer à la confirmation). */
    private String documentSourcePath;

    /** Contraventions nouvelles à réviser (chauffeur proposé, statut de rattachement). */
    @Builder.Default
    private List<Contravention> candidats = new ArrayList<>();

    /** Numéros déjà présents en base, exclus de l'import (relevés cumulatifs). */
    @Builder.Default
    private List<String> doublonsIgnores = new ArrayList<>();
}
