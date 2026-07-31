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
     * Rattache chaque ligne à ce détail, à appeler juste avant l'enregistrement.
     *
     * <p>Le côté propriétaire de la clé étrangère est l'enfant : sans cet appel,
     * les lignes partent en base avec {@code detail_maintenance_id} nul. Rien ne
     * peut s'en charger à notre place — MapStruct saute les {@code @AfterMapping}
     * lorsqu'il construit par builder, et un callback {@code @PreUpdate} ne se
     * déclenche pas sur un détail dont aucune colonne ne change, ce qui est
     * précisément le cas quand on ne fait que remplacer ses lignes.
     */
    public void rattacherElements() {
        if (elements == null) return;
        for (ElementMaintenanceEntity element : elements) {
            element.setDetailMaintenance(this);
        }
    }
}
