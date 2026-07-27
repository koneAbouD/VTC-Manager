package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import jakarta.persistence.Column;
import jakarta.persistence.MappedSuperclass;
import lombok.Getter;
import lombok.Setter;
import org.springframework.data.annotation.CreatedBy;
import org.springframework.data.annotation.LastModifiedBy;

/**
 * Socle des écritures financières : à l'horodatage s'ajoute l'auteur.
 *
 * <p>Une écriture qui touche l'argent doit pouvoir être rattachée à quelqu'un —
 * c'est ce qui rend un encaissement, une annulation ou un comptage de caisse
 * opposables. Les entités de référentiel, elles, se contentent
 * d'{@link AbstractAuditEntity}.
 */
@Getter
@Setter
@MappedSuperclass
public abstract class AbstractEcritureAuditEntity extends AbstractAuditEntity {

    @CreatedBy
    @Column(name = "created_by", updatable = false, length = 255)
    private String createdBy;

    @LastModifiedBy
    @Column(name = "updated_by", length = 255)
    private String updatedBy;
}
