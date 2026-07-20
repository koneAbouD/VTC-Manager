package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import org.springframework.data.domain.Sort;
import com.tmk.vtcmanager.application.domain.vehicule.TypeActivite;
import com.tmk.vtcmanager.application.ports.persistence.TypeActiviteRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.TypeActiviteJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.TypeActivitePersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
@RequiredArgsConstructor
public class TypeActiviteRepositoryAdapter implements TypeActiviteRepository {

    private final TypeActiviteJpaRepository jpaRepository;
    private final TypeActivitePersistenceMapper mapper;

    @Override
    public TypeActivite save(TypeActivite typeActivite) {
        return mapper.toDomain(jpaRepository.save(mapper.toEntity(typeActivite)));
    }

    @Override
    public List<TypeActivite> findAll() {
        return jpaRepository.findAll(Sort.by(Sort.Direction.DESC, "createdAt")).stream()
                .map(mapper::toDomain)
                .toList();
    }

    @Override
    public List<TypeActivite> findAllActifs() {
        return jpaRepository.findByActifTrueOrderByNomAsc().stream()
                .map(mapper::toDomain)
                .toList();
    }

    @Override
    public Optional<TypeActivite> findById(Long id) {
        return jpaRepository.findById(id).map(mapper::toDomain);
    }

    @Override
    public Optional<TypeActivite> findByNom(String nom) {
        return jpaRepository.findByNom(nom).map(mapper::toDomain);
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
