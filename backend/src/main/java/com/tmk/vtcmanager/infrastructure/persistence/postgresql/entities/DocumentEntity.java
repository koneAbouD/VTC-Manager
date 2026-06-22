package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import com.tmk.vtcmanager.application.domain.chauffeur.TypePermis;
import com.tmk.vtcmanager.application.domain.document.DocumentStatut;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;
import java.util.Set;

@Entity
@Table(name = DocumentEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DocumentEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "documents";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "type_document_id", nullable = false)
    private TypeDocumentEntity typeDocument;

    private String reference;

    @Column(name = "date_emission")
    private LocalDate dateEmission;

    @Column(name = "date_expiration")
    private LocalDate dateExpiration;

    @Enumerated(EnumType.STRING)
    @Column(length = 20, nullable = false)
    private DocumentStatut statut;

    @Column(name = "fichier_url")
    private String fichierUrl;

    @Column(name = "fichier_nom")
    private String fichierNom;

    @Column(name = "fichier_type")
    private String fichierType;

    @Enumerated(EnumType.STRING)
    @Column(name = "cible", length = 15, nullable = false)
    private com.tmk.vtcmanager.application.domain.document.CibleDocument cible;

    @Column(name = "cible_id", nullable = false)
    private Long cibleId;

    @Column(name = "date_archivage")
    private LocalDate dateArchivage;

    @Column(name = "archived_by")
    private String archivedBy;

    @Column(name = "raison_archivage")
    private String raisonArchivage;

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "document_categories", joinColumns = @JoinColumn(name = "document_id"))
    @Enumerated(EnumType.STRING)
    @Column(name = "categorie", length = 5)
    private Set<TypePermis> categorie;

    @Column(name = "permanence")
    private Boolean permanence;
}