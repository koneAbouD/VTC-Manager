package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.MaintenanceEntity;
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

            if (!Long.class.equals(query.getResultType())) {
                query.orderBy(cb.asc(root.get("datePrevue")));
            }

            return cb.and(predicates.toArray(new Predicate[0]));
        };
    }
}
