package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.application.domain.operation.OperationFinanciereFiltres;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.OperationFinanciereEntity;
import jakarta.persistence.criteria.JoinType;
import jakarta.persistence.criteria.Predicate;
import org.springframework.data.jpa.domain.Specification;

import java.util.ArrayList;
import java.util.List;

public class OperationFinanciereSpecs {

    private OperationFinanciereSpecs() {}

    public static Specification<OperationFinanciereEntity> byCriteres(OperationFinanciereFiltres f) {
        return (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();

            boolean filterByCategorie    = f.categorieCode() != null && !f.categorieCode().isBlank();
            boolean filterBySousCategorie = f.sousCategorieLibelle() != null && !f.sousCategorieLibelle().isBlank();
            boolean hasRecherche         = f.recherche()     != null && !f.recherche().isBlank();

            // Joins créés une seule fois et réutilisés pour éviter les doublons
            var cat = (filterByCategorie || hasRecherche) ? root.join("categorie",    JoinType.LEFT) : null;
            var sc  = (filterBySousCategorie || hasRecherche) ? root.join("sousCategorie", JoinType.LEFT) : null;
            var ch  = hasRecherche ? root.join("chauffeur",     JoinType.LEFT) : null;
            var v   = hasRecherche ? root.join("vehicule",      JoinType.LEFT) : null;

            if (f.typeOperation() != null) {
                predicates.add(cb.equal(root.get("typeOperation"), f.typeOperation()));
            }
            if (f.statut() != null) {
                predicates.add(cb.equal(root.get("statut"), f.statut()));
            }
            if (f.debut() != null) {
                predicates.add(cb.greaterThanOrEqualTo(root.get("dateOperation"), f.debut()));
            }
            if (f.fin() != null) {
                predicates.add(cb.lessThanOrEqualTo(root.get("dateOperation"), f.fin()));
            }
            if (f.vehiculeId() != null) {
                predicates.add(cb.equal(root.get("vehicule").get("id"), f.vehiculeId()));
            }
            if (f.chauffeurId() != null) {
                predicates.add(cb.equal(root.get("chauffeur").get("id"), f.chauffeurId()));
            }
            if (filterByCategorie) {
                predicates.add(cb.equal(cb.upper(cat.get("code")), f.categorieCode().toUpperCase()));
            }
            if (filterBySousCategorie) {
                predicates.add(cb.equal(cb.lower(sc.get("libelle")), f.sousCategorieLibelle().toLowerCase()));
            }
            if (hasRecherche) {
                String pattern = "%" + f.recherche().toLowerCase() + "%";
                predicates.add(cb.or(
                    cb.like(cb.lower(root.get("reference")),    pattern),
                    cb.like(cb.lower(cat.get("libelle")),       pattern),
                    cb.like(cb.lower(sc.get("libelle")),        pattern),
                    cb.like(cb.lower(ch.get("nom")),            pattern),
                    cb.like(cb.lower(ch.get("prenom")),         pattern),
                    cb.like(cb.lower(v.get("immatriculation")), pattern)
                ));
            }

            // Tri uniquement sur les requêtes de sélection (pas les count)
            if (!Long.class.equals(query.getResultType())) {
                query.orderBy(
                    cb.desc(root.get("dateOperation")),
                    cb.desc(root.get("createdAt"))
                );
            }

            return cb.and(predicates.toArray(new Predicate[0]));
        };
    }
}
