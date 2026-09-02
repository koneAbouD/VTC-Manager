package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import com.tmk.vtcmanager.application.domain.reaffectation.ReaffectationChauffeur;
import com.tmk.vtcmanager.application.ports.persistence.ReaffectationChauffeurRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ReaffectationChauffeurEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.ReaffectationChauffeurJpaRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Component
@RequiredArgsConstructor
public class ReaffectationChauffeurRepositoryAdapter implements ReaffectationChauffeurRepository {

    private final ReaffectationChauffeurJpaRepository jpaRepository;

    @Override
    @Transactional
    public ReaffectationChauffeur save(ReaffectationChauffeur reaffectation) {
        return toDomain(jpaRepository.save(toEntity(reaffectation)));
    }

    @Override
    @Transactional(readOnly = true)
    public List<ReaffectationChauffeur> findByDocument(TypeDocumentCreance document, Long documentId) {
        return jpaRepository.findByDocumentTypeAndDocumentIdOrderByIdDesc(document, documentId)
                .stream().map(this::toDomain).toList();
    }

    private ReaffectationChauffeurEntity toEntity(ReaffectationChauffeur d) {
        return ReaffectationChauffeurEntity.builder()
                .id(d.getId())
                .documentType(d.getDocument())
                .documentId(d.getDocumentId())
                .vehiculeId(d.getVehiculeId())
                .dateDocument(d.getDateDocument())
                .ancienChauffeurId(d.getAncienChauffeurId())
                .nouveauChauffeurId(d.getNouveauChauffeurId())
                .motif(d.getMotif())
                .operationsReprises(d.getOperationsReprises())
                .penalitesReprises(d.getPenalitesReprises())
                .createdBy(d.getCreatedBy())
                .build();
    }

    private ReaffectationChauffeur toDomain(ReaffectationChauffeurEntity e) {
        return ReaffectationChauffeur.builder()
                .id(e.getId())
                .document(e.getDocumentType())
                .documentId(e.getDocumentId())
                .vehiculeId(e.getVehiculeId())
                .dateDocument(e.getDateDocument())
                .ancienChauffeurId(e.getAncienChauffeurId())
                .nouveauChauffeurId(e.getNouveauChauffeurId())
                .motif(e.getMotif())
                .operationsReprises(e.getOperationsReprises())
                .penalitesReprises(e.getPenalitesReprises())
                .createdBy(e.getCreatedBy())
                .createdAt(e.getCreatedAt())
                .build();
    }
}
