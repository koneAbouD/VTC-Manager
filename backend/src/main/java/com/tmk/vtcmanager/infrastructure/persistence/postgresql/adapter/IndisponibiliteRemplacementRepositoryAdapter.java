package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.indisponibilite.IndisponibiliteRemplacement;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteRemplacementRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.IndisponibiliteRemplacementEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.IndisponibiliteRemplacementJpaRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Component
@RequiredArgsConstructor
public class IndisponibiliteRemplacementRepositoryAdapter
        implements IndisponibiliteRemplacementRepository {

    private final IndisponibiliteRemplacementJpaRepository jpaRepository;

    @Override
    public IndisponibiliteRemplacement save(IndisponibiliteRemplacement r) {
        return toDomain(jpaRepository.save(toEntity(r)));
    }

    @Override
    public List<IndisponibiliteRemplacement> findByIndisponibiliteId(Long indisponibiliteId) {
        return jpaRepository.findByIndisponibiliteId(indisponibiliteId).stream()
                .map(this::toDomain)
                .toList();
    }

    @Override
    @Transactional
    public void deleteByIndisponibiliteId(Long indisponibiliteId) {
        jpaRepository.deleteByIndisponibiliteId(indisponibiliteId);
    }

    private IndisponibiliteRemplacementEntity toEntity(IndisponibiliteRemplacement r) {
        return IndisponibiliteRemplacementEntity.builder()
                .id(r.getId())
                .indisponibiliteId(r.getIndisponibiliteId())
                .programmeChauffeurId(r.getProgrammeChauffeurId())
                .chauffeurTitulaireId(r.getChauffeurTitulaireId())
                .build();
    }

    private IndisponibiliteRemplacement toDomain(IndisponibiliteRemplacementEntity e) {
        return IndisponibiliteRemplacement.builder()
                .id(e.getId())
                .indisponibiliteId(e.getIndisponibiliteId())
                .programmeChauffeurId(e.getProgrammeChauffeurId())
                .chauffeurTitulaireId(e.getChauffeurTitulaireId())
                .build();
    }
}
