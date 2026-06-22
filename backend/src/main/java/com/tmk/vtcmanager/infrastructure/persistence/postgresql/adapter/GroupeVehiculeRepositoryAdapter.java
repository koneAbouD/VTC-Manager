package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.groupe.GroupeVehicule;
import com.tmk.vtcmanager.application.ports.persistence.GroupeVehiculeRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.GroupeVehiculeJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.GroupeVehiculePersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

@Repository
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class GroupeVehiculeRepositoryAdapter implements GroupeVehiculeRepository {

    private final GroupeVehiculeJpaRepository jpaRepository;
    private final GroupeVehiculePersistenceMapper mapper;

    @Override
    @Transactional
    public GroupeVehicule save(GroupeVehicule groupe) {
        var entity = mapper.toEntity(groupe);
        if (entity.getGestionnaire() != null) {
            entity.getGestionnaire().setGroupe(entity);
        }
        GroupeVehicule saved = mapper.toDomain(jpaRepository.save(entity));
        // Rechargement avec JOIN FETCH pour éviter LazyInitializationException
        return jpaRepository.findByIdWithRelations(saved.getId())
                .map(mapper::toDomain)
                .orElse(saved);
    }

    @Override
    public Optional<GroupeVehicule> findById(Long id) {
        return jpaRepository.findByIdWithRelations(id).map(mapper::toDomain);
    }

    @Override
    public List<GroupeVehicule> findAll() {
        return mapper.toDomainList(jpaRepository.findAllWithRelations());
    }

    @Override
    @Transactional
    public void deleteById(Long id) {
        jpaRepository.deleteById(id);
    }

    @Override
    public boolean existsById(Long id) {
        return jpaRepository.existsById(id);
    }

    @Override
    public boolean existsByNom(String nom) {
        return jpaRepository.existsByNom(nom);
    }
}