package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import jakarta.persistence.*;
import lombok.*;

import java.util.List;

@Entity
@Table(name = DetailMaintenanceEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DetailMaintenanceEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "details_maintenance";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToMany(mappedBy = "detailMaintenance", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    private List<ElementMaintenanceEntity> elements;

    /**
     * Garantit la cohérence de la relation bidirectionnelle avant chaque
     * persistance : sans cela les enfants seraient insérés avec
     * detail_maintenance_id = NULL (le côté propriétaire de la FK est l'enfant).
     * Posé au niveau entité pour être indépendant du mapper — MapStruct peut
     * inliner le mapping imbriqué et sauter le @AfterMapping du mapper de détail.
     */
    @PrePersist
    @PreUpdate
    private void synchroniserElements() {
        if (elements != null) {
            for (ElementMaintenanceEntity element : elements) {
                element.setDetailMaintenance(this);
            }
        }
    }
}
