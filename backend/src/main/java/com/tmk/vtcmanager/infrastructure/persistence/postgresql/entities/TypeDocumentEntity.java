package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import com.tmk.vtcmanager.application.domain.document.CibleDocument;
import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import lombok.*;

@Entity
@Table(name = TypeDocumentEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TypeDocumentEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "types_document";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @NotBlank
    @Column(nullable = false, unique = true)
    private String nom;

    @Enumerated(EnumType.STRING)
    @Column(length = 20, nullable = false)
    private CibleDocument cible;

    @Column(nullable = false)
    private boolean obligatoire;

    @Column(nullable = false)
    private boolean actif;
}