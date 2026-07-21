package com.tmk.vtcmanager.interfaces.rest.parametrage.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.util.List;

/**
 * Description d'un champ d'un référentiel, destinée au front générique de
 * paramétrage : il en déduit dynamiquement le formulaire (type de contrôle,
 * obligatoire, source d'une liste déroulante, etc.).
 */
@Schema(description = "Métadonnées d'un champ d'un référentiel (piloté par le front générique de paramétrage).")
public record ChampDescriptorResponse(

        @Schema(description = "Nom technique du champ (clé JSON dans les requêtes/réponses).", example = "nom")
        String nom,

        @Schema(description = "Libellé affiché à l'utilisateur.", example = "Nom")
        String label,

        @Schema(description = "Type de contrôle à afficher.",
                allowableValues = {"text", "number", "bool", "color", "date", "reference", "enum", "image"},
                example = "text")
        String type,

        @Schema(description = "Champ obligatoire à la saisie.", example = "true")
        boolean obligatoire,

        @Schema(description = "Champ modifiable. false = affiché en lecture seule (ex. clé immuable).", example = "true")
        boolean editable,

        @Schema(description = "Pour type=reference : clé du référentiel source de la liste déroulante.",
                example = "types-vehicules", nullable = true)
        String refKey,

        @Schema(description = "Pour type=enum : valeurs autorisées (en lecture).", nullable = true)
        List<String> options
) {

    public static ChampDescriptorResponse texte(String nom, String label, boolean obligatoire) {
        return new ChampDescriptorResponse(nom, label, "text", obligatoire, true, null, null);
    }

    public static ChampDescriptorResponse nombre(String nom, String label, boolean obligatoire) {
        return new ChampDescriptorResponse(nom, label, "number", obligatoire, true, null, null);
    }

    public static ChampDescriptorResponse booleen(String nom, String label) {
        return new ChampDescriptorResponse(nom, label, "bool", false, true, null, null);
    }

    public static ChampDescriptorResponse couleur(String nom, String label, boolean obligatoire) {
        return new ChampDescriptorResponse(nom, label, "color", obligatoire, true, null, null);
    }

    public static ChampDescriptorResponse reference(String nom, String label, boolean obligatoire, String refKey) {
        return new ChampDescriptorResponse(nom, label, "reference", obligatoire, true, refKey, null);
    }

    /** Champ énuméré : liste déroulante des valeurs autorisées (codes d'enum). */
    public static ChampDescriptorResponse enumeration(
            String nom, String label, boolean obligatoire, java.util.List<String> valeurs) {
        return new ChampDescriptorResponse(nom, label, "enum", obligatoire, true, null, valeurs);
    }

    /** Champ image : upload d'un fichier via {endpoint}/image, la valeur stockée est le nom d'objet. */
    public static ChampDescriptorResponse image(String nom, String label, boolean obligatoire) {
        return new ChampDescriptorResponse(nom, label, "image", obligatoire, true, null, null);
    }

    /** Champ non modifiable (clé immuable ou dérivé). */
    public static ChampDescriptorResponse lectureSeule(String nom, String label) {
        return new ChampDescriptorResponse(nom, label, "text", false, false, null, null);
    }
}
