package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceFiltres;
import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ElementMaintenanceEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.MaintenanceEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.spec.RechercheVehiculeChauffeur;
import jakarta.persistence.criteria.AbstractQuery;
import jakarta.persistence.criteria.CriteriaBuilder;
import jakarta.persistence.criteria.JoinType;
import jakarta.persistence.criteria.Predicate;
import jakarta.persistence.criteria.Root;
import jakarta.persistence.criteria.Subquery;
import org.springframework.data.jpa.domain.Specification;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

public class MaintenanceSpecs {

    private MaintenanceSpecs() {}

    public static Specification<MaintenanceEntity> byFiltres(
            LocalDate dateDebut,
            LocalDate dateFin,
            MaintenanceStatus statut,
            Long vehiculeId) {
        return byFiltres(
                new MaintenanceFiltres(dateDebut, dateFin, statut, vehiculeId, null, null, false),
                LocalDate.now());
    }

    /**
     * @param aujourdhui jour de référence du filtre « en retard »
     */
    public static Specification<MaintenanceEntity> byFiltres(MaintenanceFiltres filtres,
                                                             LocalDate aujourdhui) {
        return (root, query, cb) -> {
            // Tri antéchronologique (plus récentes d'abord), avec l'id
            // décroissant comme départage pour une pagination déterministe
            // quand plusieurs maintenances partagent la même date prévue.
            if (!Long.class.equals(query.getResultType())) {
                query.orderBy(cb.desc(root.get("datePrevue")), cb.desc(root.get("id")));
            }
            return cb.and(predicats(filtres, aujourdhui, root, query, cb).toArray(new Predicate[0]));
        };
    }

    /**
     * Prédicats communs à la liste et aux cumuls : un seul endroit à lire pour
     * savoir ce que « la sélection affichée » recouvre.
     */
    public static List<Predicate> predicats(MaintenanceFiltres filtres, LocalDate aujourdhui,
                                            Root<MaintenanceEntity> root, AbstractQuery<?> query,
                                            CriteriaBuilder cb) {
        List<Predicate> predicates = new ArrayList<>();

        if (filtres.dateDebut() != null) {
            predicates.add(cb.greaterThanOrEqualTo(root.get("datePrevue"), filtres.dateDebut()));
        }
        if (filtres.dateFin() != null) {
            predicates.add(cb.lessThanOrEqualTo(root.get("datePrevue"), filtres.dateFin()));
        }
        if (filtres.statut() != null) {
            predicates.add(cb.equal(root.get("statut"), filtres.statut()));
        }
        if (filtres.vehiculeId() != null) {
            predicates.add(cb.equal(root.get("vehicule").get("id"), filtres.vehiculeId()));
        }
        if (!filtres.categorieTypeIds().isEmpty()) {
            predicates.add(root.get("categorieType").get("id").in(filtres.categorieTypeIds()));
        }
        // En retard : encore au programme alors que sa date est passée. Un état
        // calculé, pas un statut : la maintenance reste planifiée en base.
        if (filtres.enRetard()) {
            predicates.add(cb.equal(root.get("statut"), MaintenanceStatus.PLANIFIEE));
            predicates.add(cb.lessThan(root.get("datePrevue"), aujourdhui));
        }
        if (RechercheVehiculeChauffeur.estRenseignee(filtres.recherche())) {
            String motif = RechercheVehiculeChauffeur.motif(filtres.recherche());
            // Jointures en LEFT : une maintenance sans prestataire, ou dont
            // le type n'est pas encore rattaché à une catégorie, doit rester
            // trouvable par les autres critères.
            var vehicule = root.join("vehicule", JoinType.LEFT);
            var categorie = root.join("categorieType", JoinType.LEFT);
            var partenaire = root.join("partenaire", JoinType.LEFT);
            predicates.add(cb.or(
                    // Le type se cherche par son libellé — celui que la
                    // liste affiche — comme par son code historique.
                    cb.like(cb.lower(categorie.get("libelle")), motif),
                    cb.like(cb.lower(root.get("type")), motif),
                    cb.like(cb.lower(vehicule.get("immatriculation")), motif),
                    cb.like(cb.lower(partenaire.get("nom")), motif),
                    cb.exists(elementCorrespondant(motif, root, query, cb))));
        }

        return predicates;
    }

    /**
     * Un élément de l'intervention dont le nom correspond — saisi librement ou
     * repris du catalogue. En sous-requête plutôt qu'en jointure : une
     * intervention à plusieurs éléments correspondants compterait sinon pour
     * autant de lignes dans la page comme dans les cumuls.
     */
    private static Subquery<Long> elementCorrespondant(String motif, Root<MaintenanceEntity> root,
                                                       AbstractQuery<?> query, CriteriaBuilder cb) {
        Subquery<Long> sousRequete = query.subquery(Long.class);
        Root<ElementMaintenanceEntity> element = sousRequete.from(ElementMaintenanceEntity.class);
        var catalogue = element.join("catalogueElement", JoinType.LEFT);
        return sousRequete.select(element.get("id")).where(
                cb.equal(element.get("detailMaintenance").get("id"),
                        root.get("detailMaintenance").get("id")),
                cb.or(
                        cb.like(cb.lower(element.get("libelle")), motif),
                        cb.like(cb.lower(catalogue.get("libelle")), motif)));
    }
}
