package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciereFiltres;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.OperationFinanciereJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.OperationFinanciereSpecs;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.OperationFinancierePersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class OperationFinanciereRepositoryAdapter implements OperationFinanciereRepository {

    private final OperationFinanciereJpaRepository jpaRepository;
    private final OperationFinancierePersistenceMapper mapper;

    @Override
    public OperationFinanciere save(OperationFinanciere operation) {
        return mapper.toDomain(jpaRepository.save(mapper.toEntity(operation)));
    }

    @Override
    public Optional<OperationFinanciere> findById(Long id) {
        return jpaRepository.findById(id).map(mapper::toDomain);
    }

    @Override
    public List<OperationFinanciere> findByCriteres(OperationFinanciereFiltres filtres) {
        return mapper.toDomainList(jpaRepository.findAll(OperationFinanciereSpecs.byCriteres(filtres)));
    }

    @Override
    public PageResult<OperationFinanciere> findPageByCriteres(OperationFinanciereFiltres filtres, int page, int size) {
        // Le tri est porté par la Specification (dateOperation desc) ; on passe
        // donc un PageRequest non trié pour éviter tout conflit d'ordre.
        Page<OperationFinanciere> result = jpaRepository
                .findAll(OperationFinanciereSpecs.byCriteres(filtres), PageRequest.of(page, size))
                .map(mapper::toDomain);
        return new PageResult<>(
                result.getContent(),
                result.getNumber(),
                result.getSize(),
                result.getTotalElements());
    }

    @Override
    public List<OperationFinanciere> findByChauffeurId(Long chauffeurId) {
        return mapper.toDomainList(jpaRepository.findByChauffeurId(chauffeurId));
    }

    @Override
    public List<OperationFinanciere> findByVehiculeId(Long vehiculeId) {
        return mapper.toDomainList(jpaRepository.findByVehiculeId(vehiculeId));
    }

    @Override
    public boolean existsByReference(String reference) {
        return jpaRepository.existsByReference(reference);
    }

    @Override
    public void deleteById(Long id) {
        jpaRepository.deleteById(id);
    }
}
