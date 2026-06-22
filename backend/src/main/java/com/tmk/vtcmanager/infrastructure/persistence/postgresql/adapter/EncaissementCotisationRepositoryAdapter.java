package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.cotisation.EncaissementCotisation;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementCotisationRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.EncaissementCotisationEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.EncaissementCotisationJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.LigneCotisationJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.OperationFinanciereJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.EncaissementCotisationPersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class EncaissementCotisationRepositoryAdapter implements EncaissementCotisationRepository {

    private final EncaissementCotisationJpaRepository jpaRepository;
    private final LigneCotisationJpaRepository ligneCotisationJpaRepository;
    private final OperationFinanciereJpaRepository operationFinanciereJpaRepository;
    private final EncaissementCotisationPersistenceMapper mapper;

    @Override
    @Transactional
    public EncaissementCotisation save(EncaissementCotisation encaissement) {
        EncaissementCotisationEntity entity = EncaissementCotisationEntity.builder()
                .ligneCotisation(ligneCotisationJpaRepository.getReferenceById(encaissement.getLigneCotisationId()))
                .operationFinanciere(encaissement.getOperationFinanciereId() != null
                        ? operationFinanciereJpaRepository.getReferenceById(encaissement.getOperationFinanciereId())
                        : null)
                .montant(encaissement.getMontant())
                .modeEncaissement(encaissement.getModeEncaissement())
                .dateEncaissement(encaissement.getDateEncaissement())
                .reference(encaissement.getReference())
                .commentaire(encaissement.getCommentaire())
                .build();

        return mapper.toDomain(jpaRepository.save(entity));
    }

    @Override
    public Optional<EncaissementCotisation> findById(Long id) {
        return jpaRepository.findById(id).map(mapper::toDomain);
    }

    @Override
    public List<EncaissementCotisation> findByLigneCotisationId(Long ligneCotisationId) {
        return mapper.toDomainList(jpaRepository.findByLigneCotisationId(ligneCotisationId));
    }
}
