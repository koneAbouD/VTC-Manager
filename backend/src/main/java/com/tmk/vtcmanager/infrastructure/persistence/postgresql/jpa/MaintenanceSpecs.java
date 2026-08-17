package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.MaintenanceEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.spec.RechercheVehiculeChauffeur;
import jakarta.persistence.criteria.JoinType;
import jakarta.persistence.criteria.Predicate;
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
        return byFiltres(dateDebut, dateFin, statut, vehiculeId, null);
    }

    /**
     * @param recherche mot-clé libre : type de maintenance (code et libellé de
     *                  catégorie), immatriculation du véhicule ou nom du
     *                  prestataire ; ignoré s'il est vide
     */
    public static Specification<MaintenanceEntity> byFiltres(
            LocalDate dateDebut,
            LocalDate dateFin,
            MaintenanceStatus statut,
            Long vehiculeId,
            String recherche) {

        return (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();

            if (dateDebut != null) {
                predicates.add(cb.greaterThanOrEqualTo(root.get("datePrevue"), dateDebut));
            }
            if (dateFin != null) {
                predicates.add(cb.lessThanOrEqualTo(root.get("datePrevue"), dateFin));
            }
            if (statut != null) {
                predicates.add(cb.equal(root.get("statut"), statut));
            }
            if (vehiculeId != null) {
                predicates.add(cb.equal(root.get("vehicule").get("id"), vehiculeId));
            }
            if (RechercheVehiculeChauffeur.estRenseignee(recherche)) {
                String motif = RechercheVehiculeChauffeur.motif(recherche);
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
                        cb.like(cb.lower(partenaire.get("nom")), motif)));
            }

            // Tri antéchronologique (plus récentes d'abord), avec l'id
            // décroissant comme départage pour une pagination déterministe
            // quand plusieurs maintenances partagent la même date prévue.
            if (!Long.class.equals(query.getResultType())) {
                query.orderBy(cb.desc(root.get("datePrevue")), cb.desc(root.get("id")));
            }

            return cb.and(predicates.toArray(new Predicate[0]));
        };
    }
}
