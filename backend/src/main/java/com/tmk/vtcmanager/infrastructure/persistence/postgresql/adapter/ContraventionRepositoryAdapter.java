package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import org.springframework.data.domain.Sort;
import com.tmk.vtcmanager.application.domain.contravention.Contravention;
import com.tmk.vtcmanager.application.domain.contravention.ContraventionStatus;
import com.tmk.vtcmanager.application.ports.persistence.ContraventionRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.ContraventionJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.ContraventionPersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class ContraventionRepositoryAdapter implements ContraventionRepository {

    private final ContraventionJpaRepository jpaRepository;
    private final ContraventionPersistenceMapper mapper;

    @Override
    public Contravention save(Contravention contravention) {
        return mapper.toDomain(jpaRepository.save(mapper.toEntity(contravention)));
    }

    @Override
    public Optional<Contravention> findById(Long id) {
        return jpaRepository.findById(id).map(mapper::toDomain);
    }

    @Override
    public List<Contravention> findAll() {
        return mapper.toDomainList(jpaRepository.findAll(Sort.by(Sort.Direction.DESC, "createdAt")));
    }

    @Override
    public List<Contravention> findByChauffeurId(Long chauffeurId) {
        return mapper.toDomainList(jpaRepository.findByChauffeurIdOrderByCreatedAtDesc(chauffeurId));
    }

    @Override
    public List<Contravention> findByVehiculeId(Long vehiculeId) {
        return mapper.toDomainList(jpaRepository.findByVehiculeIdOrderByCreatedAtDesc(vehiculeId));
    }

    @Override
    public List<Contravention> findByStatut(ContraventionStatus statut) {
        return mapper.toDomainList(jpaRepository.findByStatut(statut));
    }

    @Override
    public void deleteById(Long id) {
        jpaRepository.deleteById(id);
    }
}
