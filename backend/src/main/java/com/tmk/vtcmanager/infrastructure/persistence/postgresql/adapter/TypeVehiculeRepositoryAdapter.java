package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import org.springframework.data.domain.Sort;
import com.tmk.vtcmanager.application.domain.vehicule.TypeVehicule;
import com.tmk.vtcmanager.application.ports.persistence.TypeVehiculeRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.TypeVehiculeEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.TypeVehiculeJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.TypeVehiculePersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
@RequiredArgsConstructor
public class TypeVehiculeRepositoryAdapter implements TypeVehiculeRepository {

    private final TypeVehiculeJpaRepository jpaRepository;
    private final TypeVehiculePersistenceMapper mapper;

    @Override
    public TypeVehicule save(TypeVehicule typeVehicule) {
        TypeVehiculeEntity entity = mapper.toEntity(typeVehicule);
        TypeVehiculeEntity savedEntity = jpaRepository.save(entity);
        return mapper.toDomain(savedEntity);
    }

    @Override
    public Optional<TypeVehicule> findById(Long id) {
        return jpaRepository.findById(id)
                .map(mapper::toDomain);
    }

    @Override
    public List<TypeVehicule> findAll() {
        return jpaRepository.findAll(Sort.by(Sort.Direction.DESC, "createdAt")).stream()
                .map(mapper::toDomain)
                .toList();
    }

    @Override
    public List<TypeVehicule> findAllActifs() {
        return jpaRepository.findByActifTrueOrderByNomAsc().stream()
                .map(mapper::toDomain)
                .toList();
    }

    @Override
    public Optional<TypeVehicule> findByNom(String nom) {
        return jpaRepository.findByNom(nom)
                .map(mapper::toDomain);
    }

    @Override
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
