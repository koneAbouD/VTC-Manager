package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import jakarta.persistence.*;
import lombok.*;


@Entity
@Table(name = CategorieOperationEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CategorieOperationEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "categories_operation";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 50)
    private String code;

    @Column(nullable = false)
    private String libelle;

    @Enumerated(EnumType.STRING)
    @Column(name = "type_operation", nullable = false, length = 20)
    private TypeOperation typeOperation;

    @Column(nullable = false)
    private boolean actif;

    @OneToOne(mappedBy = "categorie", fetch = FetchType.LAZY)
    private SousCategorieOperationEntity sousCategorie;
}
