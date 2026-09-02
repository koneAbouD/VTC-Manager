package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDate;

/**
 * Trace d'un changement de débiteur sur une créance.
 *
 * <p>Les chauffeurs et le véhicule sont portés par leur identifiant nu, sans
 * association : ce journal se lit tel qu'il a été écrit, et n'a jamais besoin
 * de charger la fiche d'un chauffeur pour dire ce qui s'est passé ce jour-là.
 */
@Entity
@Table(name = ReaffectationChauffeurEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ReaffectationChauffeurEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "reaffectations_chauffeur";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(name = "document_type", nullable = false, length = 20)
    private TypeDocumentCreance documentType;

    @Column(name = "document_id", nullable = false)
    private Long documentId;

    @Column(name = "vehicule_id")
    private Long vehiculeId;

    @Column(name = "date_document")
    private LocalDate dateDocument;

    @Column(name = "ancien_chauffeur_id", nullable = false)
    private Long ancienChauffeurId;

    @Column(name = "nouveau_chauffeur_id", nullable = false)
    private Long nouveauChauffeurId;

    @Column(name = "motif", nullable = false, columnDefinition = "text")
    private String motif;

    @Column(name = "operations_reprises", nullable = false)
    private int operationsReprises;

    @Column(name = "penalites_reprises", nullable = false)
    private int penalitesReprises;

    @Column(name = "created_by", length = 255)
    private String createdBy;
}
