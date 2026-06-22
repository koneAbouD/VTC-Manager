package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.penalite.EncaissementPenalite;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementPenaliteRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.EncaissementPenaliteEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.EncaissementPenaliteJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.LignePenaliteJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.OperationFinanciereJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.LignePenalitePersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class EncaissementPenaliteRepositoryAdapter implements EncaissementPenaliteRepository {

    private final EncaissementPenaliteJpaRepository jpaRepository;
    private final LignePenaliteJpaRepository lignePenaliteJpaRepository;
    private final OperationFinanciereJpaRepository operationFinanciereJpaRepository;
    private final LignePenalitePersistenceMapper mapper;

    @Override
    @Transactional
    public EncaissementPenalite save(EncaissementPenalite encaissement) {
        EncaissementPenaliteEntity entity = EncaissementPenaliteEntity.builder()
                .lignePenalite(lignePenaliteJpaRepository.getReferenceById(encaissement.getLignePenaliteId()))
                .operationFinanciere(encaissement.getOperationFinanciereId() != null
                        ? operationFinanciereJpaRepository.getReferenceById(encaissement.getOperationFinanciereId())
                        : null)
                .montant(encaissement.getMontant())
                .modeEncaissement(encaissement.getModeEncaissement())
                .dateEncaissement(encaissement.getDateEncaissement())
                .reference(encaissement.getReference())
                .commentaire(encaissement.getCommentaire())
                .build();

        return mapper.toEncaissementDomain(jpaRepository.save(entity));
    }

    @Override
    public Optional<EncaissementPenalite> findById(Long id) {
        return jpaRepository.findById(id).map(mapper::toEncaissementDomain);
    }

    @Override
    public List<EncaissementPenalite> findByLignePenaliteId(Long lignePenaliteId) {
        return jpaRepository.findByLignePenaliteId(lignePenaliteId)
                .stream().map(mapper::toEncaissementDomain).toList();
    }
}
