package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = SousCategorieOperationEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SousCategorieOperationEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "sous_categories_operation";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 50)
    private String code;

    @Column(nullable = false)
    private String libelle;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "categorie_id", nullable = false, unique = true)
    private CategorieOperationEntity categorie;

    @Column(nullable = false)
    private boolean actif;
}
