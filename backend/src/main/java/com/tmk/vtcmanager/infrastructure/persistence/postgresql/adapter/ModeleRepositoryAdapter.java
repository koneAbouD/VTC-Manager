package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import org.springframework.data.domain.Sort;
import com.tmk.vtcmanager.application.domain.vehicule.Modele;
import com.tmk.vtcmanager.application.ports.persistence.ModeleRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ModeleEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.ModeleJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.ModelePersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
@RequiredArgsConstructor
public class ModeleRepositoryAdapter implements ModeleRepository {

    private final ModeleJpaRepository jpaRepository;
    private final ModelePersistenceMapper mapper;

    @Override
    public Modele save(Modele modele) {
        ModeleEntity entity = mapper.toEntity(modele);
        ModeleEntity savedEntity = jpaRepository.save(entity);
        return mapper.toDomain(savedEntity);
    }

    @Override
    public Optional<Modele> findById(Long id) {
        return jpaRepository.findById(id)
                .map(mapper::toDomain);
    }

    @Override
    public List<Modele> findAll() {
        return jpaRepository.findAll(Sort.by(Sort.Direction.DESC, "createdAt")).stream()
                .map(mapper::toDomain)
                .toList();
    }

    @Override
    public Optional<Modele> findByNom(String nom) {
        return jpaRepository.findByNom(nom)
                .map(mapper::toDomain);
    }

    @Override
    public List<Modele> findByMarqueId(Long marqueId) {
        return jpaRepository.findByMarqueId(marqueId).stream()
                .map(mapper::toDomain)
                .toList();
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
