package com.tmk.vtcmanager.interfaces.rest.parametrage;

import com.tmk.vtcmanager.interfaces.rest.parametrage.dto.ChampDescriptorResponse;
import com.tmk.vtcmanager.interfaces.rest.parametrage.dto.ReferentielDescriptorResponse;
import org.springframework.stereotype.Component;

import java.util.List;

import static com.tmk.vtcmanager.interfaces.rest.parametrage.dto.ChampDescriptorResponse.*;

/**
 * Catalogue des référentiels paramétrables (Lot 1 — Tier A).
 *
 * <p>Source de vérité du meta-catalogue exposé par {@link ReferentielCatalogController}.
 * Chaque entrée décrit un référentiel : son endpoint REST, s'il est éditable et
 * le schéma de ses champs. Le front générique de paramétrage s'appuie dessus
 * pour rendre listes et formulaires sans écran codé en dur.</p>
 *
 * <p>Ajouter un référentiel = ajouter une entrée ici (+ son CRUD REST). Les
 * enums de code (statuts / machines à états) ne figurent pas : non éditables.</p>
 */
@Component
public class ReferentielCatalogue {

    public List<ReferentielDescriptorResponse> descripteurs() {
        return List.of(
                typesVehicules(),
                typesActivites(),
                marques(),
                catalogueElementsMaintenance());
    }

    private ReferentielDescriptorResponse typesVehicules() {
        return new ReferentielDescriptorResponse(
                "types-vehicules",
                "Types de véhicule",
                "Catégories de véhicules (TAXI, LIVRAISON, LOCATION, …).",
                "/api/v1/types-vehicules",
                true,
                "id",
                List.of(
                        texte("nom", "Nom", true),
                        texte("description", "Description", false),
                        booleen("actif", "Actif")));
    }

    private ReferentielDescriptorResponse typesActivites() {
        return new ReferentielDescriptorResponse(
                "types-activites",
                "Types d'activité",
                "Activités exercées par un véhicule/chauffeur.",
                "/api/v1/types-activites",
                true,
                "id",
                List.of(
                        texte("nom", "Nom", true),
                        texte("description", "Description", false),
                        booleen("actif", "Actif")));
    }

    private ReferentielDescriptorResponse marques() {
        return new ReferentielDescriptorResponse(
                "marques",
                "Marques",
                "Marques de véhicules, rattachées à un type de véhicule.",
                "/api/v1/marques",
                true,
                "id",
                List.of(
                        texte("nom", "Nom", true),
                        reference("typeId", "Type de véhicule", true, "types-vehicules"),
                        texte("paysOrigine", "Pays d'origine", false),
                        booleen("actif", "Actif")));
    }

    private ReferentielDescriptorResponse catalogueElementsMaintenance() {
        return new ReferentielDescriptorResponse(
                "catalogue-elements-maintenance",
                "Éléments de maintenance",
                "Catalogue des éléments/postes utilisables dans les opérations de maintenance.",
                "/api/catalogue-elements-maintenance",
                true,
                "id",
                List.of(
                        texte("libelle", "Libellé", true),
                        nombre("montantDefaut", "Montant par défaut", false),
                        image("image", "Image", false),
                        booleen("actif", "Actif")));
    }
}
