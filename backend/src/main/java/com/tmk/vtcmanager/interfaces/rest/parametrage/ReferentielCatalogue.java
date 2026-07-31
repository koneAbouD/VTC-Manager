package com.tmk.vtcmanager.interfaces.rest.parametrage;

import com.tmk.vtcmanager.application.domain.operation.SousCategorieOperation;
import com.tmk.vtcmanager.application.ports.persistence.SousCategorieOperationRepository;
import com.tmk.vtcmanager.interfaces.rest.parametrage.dto.ChampDescriptorResponse;
import com.tmk.vtcmanager.interfaces.rest.parametrage.dto.ReferentielDescriptorResponse;
import lombok.RequiredArgsConstructor;
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
@RequiredArgsConstructor
public class ReferentielCatalogue {

    private final SousCategorieOperationRepository sousCategorieRepository;

    public List<ReferentielDescriptorResponse> descripteurs() {
        return List.of(
                typesVehicules(),
                typesActivites(),
                marques(),
                modeles(),
                typesDocument(),
                categoriesOperation(),
                balises(),
                typesPartenaire(),
                catalogueElementsMaintenance());
    }

    private ReferentielDescriptorResponse typesPartenaire() {
        return new ReferentielDescriptorResponse(
                "types-partenaire",
                "Types de partenaire",
                "Familles de partenaires (prestataire, fournisseur, administration, bailleur…).",
                "/api/v1/types-partenaire",
                true,
                "id",
                List.of(
                        texte("nom", "Nom", true),
                        texte("description", "Description", false),
                        booleen("actif", "Actif")));
    }

    private ReferentielDescriptorResponse balises() {
        return new ReferentielDescriptorResponse(
                "balises",
                "Balises GPS",
                "Balises GPS installées sur les véhicules (identifiant + n° de téléphone).",
                "/api/v1/balises",
                true,
                "id",
                List.of(
                        texte("identifiant", "Identifiant", true),
                        texte("numeroTelephone", "N° de téléphone", false),
                        booleen("actif", "Actif")));
    }

    private ReferentielDescriptorResponse modeles() {
        return new ReferentielDescriptorResponse(
                "modeles",
                "Modèles",
                "Modèles de véhicules, rattachés à une marque.",
                "/api/v1/modeles",
                true,
                "id",
                List.of(
                        texte("nom", "Nom", true),
                        reference("marqueId", "Marque", true, "marques"),
                        booleen("actif", "Actif")));
    }

    private ReferentielDescriptorResponse typesDocument() {
        return new ReferentielDescriptorResponse(
                "types-document",
                "Types de document",
                "Types de documents (carte grise, assurance, permis…) par cible.",
                "/api/v1/types-document",
                true,
                "id",
                List.of(
                        texte("nom", "Nom", true),
                        enumeration("cible", "Cible", true, List.of("VEHICULE", "CHAUFFEUR")),
                        booleen("obligatoire", "Obligatoire"),
                        booleen("actif", "Actif")));
    }

    private ReferentielDescriptorResponse categoriesOperation() {
        return new ReferentielDescriptorResponse(
                "categories-operation",
                "Catégories d'opération",
                "Catégories des opérations financières (produits, charges).",
                "/api/categories-operation",
                true,
                "id",
                List.of(
                        texte("libelle", "Libellé", true),
                        // Groupe / famille comptable : choix parmi les sous-catégories
                        // (groupes) déjà existantes. Options calculées à la volée.
                        enumeration("sousCategorieLibelle", "Sous-catégorie", true,
                                groupesSousCategorie()),
                        enumeration("typeOperation", "Type d'opération", true,
                                List.of("REVENU", "DEPENSE")),
                        enumeration("natureResultat", "Nature de résultat", true,
                                List.of("PRODUIT_EXPLOITATION", "CHARGE_VARIABLE",
                                        "CHARGE_FIXE", "HORS_RESULTAT")),
                        booleen("actif", "Actif")));
    }

    /** Libellés distincts des sous-catégories existantes (groupes comptables),
     *  triés — servent d'options à la liste déroulante « Sous-catégorie ». */
    private List<String> groupesSousCategorie() {
        return sousCategorieRepository.findAll().stream()
                .map(SousCategorieOperation::getLibelle)
                .filter(l -> l != null && !l.isBlank())
                .distinct()
                .sorted()
                .toList();
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
