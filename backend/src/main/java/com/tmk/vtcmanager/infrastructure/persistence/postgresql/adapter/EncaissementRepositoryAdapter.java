package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.recette.Encaissement;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.EncaissementEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.LigneRecetteEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.OperationFinanciereEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.EncaissementJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.LigneRecetteJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.OperationFinanciereJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.EncaissementPersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class EncaissementRepositoryAdapter implements EncaissementRepository {

    private final EncaissementJpaRepository jpaRepository;
    private final LigneRecetteJpaRepository ligneRecetteJpaRepository;
    private final OperationFinanciereJpaRepository operationFinanciereJpaRepository;
    private final EncaissementPersistenceMapper mapper;

    @Override
    @Transactional
    public Encaissement save(Encaissement encaissement) {
        LigneRecetteEntity ligne = ligneRecetteJpaRepository.getReferenceById(encaissement.getLigneRecetteId());

        OperationFinanciereEntity operation = encaissement.getOperationFinanciereId() != null
                ? operationFinanciereJpaRepository.getReferenceById(encaissement.getOperationFinanciereId())
                : null;

        EncaissementEntity entity = EncaissementEntity.builder()
                .ligneRecette(ligne)
                .operationFinanciere(operation)
                .montant(encaissement.getMontant())
                .modeEncaissement(encaissement.getModeEncaissement())
                .dateEncaissement(encaissement.getDateEncaissement())
                .reference(encaissement.getReference())
                .commentaire(encaissement.getCommentaire())
                .build();

        return mapper.toDomain(jpaRepository.save(entity));
    }

    @Override
    public Optional<Encaissement> findById(Long id) {
        return jpaRepository.findById(id).map(mapper::toDomain);
    }

    @Override
    public List<Encaissement> findByLigneRecetteId(Long ligneRecetteId) {
        return mapper.toDomainList(jpaRepository.findByLigneRecetteId(ligneRecetteId));
    }

    @Override
    public Optional<Encaissement> findByOperationFinanciereId(Long operationFinanciereId) {
        return jpaRepository.findByOperationFinanciereId(operationFinanciereId).map(mapper::toDomain);
    }

    @Override
    public void deleteById(Long id) {
        jpaRepository.deleteById(id);
    }
}
