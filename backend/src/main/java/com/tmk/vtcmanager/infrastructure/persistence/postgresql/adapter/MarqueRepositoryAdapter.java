package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import org.springframework.data.domain.Sort;
import com.tmk.vtcmanager.application.domain.vehicule.Marque;
import com.tmk.vtcmanager.application.ports.persistence.MarqueRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.MarqueEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.MarqueJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.MarquePersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
@RequiredArgsConstructor
public class MarqueRepositoryAdapter implements MarqueRepository {

    private final MarqueJpaRepository jpaRepository;
    private final MarquePersistenceMapper mapper;

    @Override
    public Marque save(Marque marque) {
        MarqueEntity entity = mapper.toEntity(marque);
        MarqueEntity savedEntity = jpaRepository.save(entity);
        return mapper.toDomain(savedEntity);
    }

    @Override
    public Optional<Marque> findById(Long id) {
        return jpaRepository.findById(id)
                .map(mapper::toDomain);
    }

    @Override
    public List<Marque> findAll() {
        return jpaRepository.findAll(Sort.by(Sort.Direction.DESC, "createdAt")).stream()
                .map(mapper::toDomain)
                .toList();
    }

    @Override
    public Optional<Marque> findByNom(String nom) {
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
