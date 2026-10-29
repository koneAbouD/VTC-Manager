package com.tmk.vtcmanager.interfaces.rest.parametrage.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.util.List;
import java.util.Map;

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
        List<String> options,

        @Schema(description = "Pour type=enum : libellé à afficher pour chaque valeur (code → libellé). "
                + "Absent quand les valeurs sont déjà lisibles.",
                example = "{\"CHARGE_FIXE\": \"Charge fixe\"}", nullable = true)
        Map<String, String> libelles,

        @Schema(description = "Pour type=reference : valeurs que doivent porter les éléments du "
                + "référentiel source pour être proposés (champ → valeur). Absent : tous sont proposés.",
                example = "{\"sousCategorieLibelle\": \"Maintenances\"}", nullable = true)
        Map<String, String> refFiltre
) {

    public static ChampDescriptorResponse texte(String nom, String label, boolean obligatoire) {
        return new ChampDescriptorResponse(nom, label, "text", obligatoire, true, null, null, null, null);
    }

    public static ChampDescriptorResponse nombre(String nom, String label, boolean obligatoire) {
        return new ChampDescriptorResponse(nom, label, "number", obligatoire, true, null, null, null, null);
    }

    public static ChampDescriptorResponse booleen(String nom, String label) {
        return new ChampDescriptorResponse(nom, label, "bool", false, true, null, null, null, null);
    }

    public static ChampDescriptorResponse couleur(String nom, String label, boolean obligatoire) {
        return new ChampDescriptorResponse(nom, label, "color", obligatoire, true, null, null, null, null);
    }

    public static ChampDescriptorResponse reference(String nom, String label, boolean obligatoire, String refKey) {
        return new ChampDescriptorResponse(nom, label, "reference", obligatoire, true, refKey, null, null, null);
    }

    /**
     * Référence restreinte aux éléments du référentiel source qui portent les
     * valeurs de [filtre] (ex. catégories d'opération de la sous-catégorie
     * « Maintenances »).
     */
    public static ChampDescriptorResponse reference(String nom, String label, boolean obligatoire,
                                                    String refKey, Map<String, String> filtre) {
        return new ChampDescriptorResponse(nom, label, "reference", obligatoire, true, refKey, null, null,
                Map.copyOf(filtre));
    }

    /** Champ énuméré dont les valeurs sont déjà lisibles (libellés de groupes, par exemple). */
    public static ChampDescriptorResponse enumeration(
            String nom, String label, boolean obligatoire, java.util.List<String> valeurs) {
        return new ChampDescriptorResponse(nom, label, "enum", obligatoire, true, null, valeurs, null, null);
    }

    /**
     * Champ énuméré sur des codes d'enum : [libelles] associe chaque code à son
     * libellé, dans l'ordre de la liste déroulante. Le code reste la valeur
     * envoyée et reçue ; seul le libellé s'affiche.
     */
    public static ChampDescriptorResponse enumeration(
            String nom, String label, boolean obligatoire, Map<String, String> libelles) {
        return new ChampDescriptorResponse(nom, label, "enum", obligatoire, true, null,
                List.copyOf(libelles.keySet()), libelles, null);
    }

    /** Champ image : upload d'un fichier via {endpoint}/image, la valeur stockée est le nom d'objet. */
    public static ChampDescriptorResponse image(String nom, String label, boolean obligatoire) {
        return new ChampDescriptorResponse(nom, label, "image", obligatoire, true, null, null, null, null);
    }

    /** Champ non modifiable (clé immuable ou dérivé). */
    public static ChampDescriptorResponse lectureSeule(String nom, String label) {
        return new ChampDescriptorResponse(nom, label, "text", false, false, null, null, null, null);
    }
}
