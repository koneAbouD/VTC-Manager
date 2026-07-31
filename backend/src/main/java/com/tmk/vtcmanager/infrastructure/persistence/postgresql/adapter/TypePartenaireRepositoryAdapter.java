package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.partenaire.TypePartenaire;
import com.tmk.vtcmanager.application.ports.persistence.TypePartenaireRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.PartenaireJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.TypePartenaireJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.TypePartenairePersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
@RequiredArgsConstructor
public class TypePartenaireRepositoryAdapter implements TypePartenaireRepository {

    private final TypePartenaireJpaRepository jpaRepository;
    private final PartenaireJpaRepository partenaireJpaRepository;
    private final TypePartenairePersistenceMapper mapper;

    @Override
    public TypePartenaire save(TypePartenaire typePartenaire) {
        return mapper.toDomain(jpaRepository.save(mapper.toEntity(typePartenaire)));
    }

    @Override
    public List<TypePartenaire> findAll() {
        return mapper.toDomainList(jpaRepository.findAllByOrderByNomAsc());
    }

    @Override
    public List<TypePartenaire> findAllActifs() {
        return mapper.toDomainList(jpaRepository.findByActifTrueOrderByNomAsc());
    }

    @Override
    public Optional<TypePartenaire> findById(Long id) {
        return jpaRepository.findById(id).map(mapper::toDomain);
    }

    @Override
    public Optional<TypePartenaire> findByNom(String nom) {
        return nom == null ? Optional.empty()
                : jpaRepository.findByNomIgnoreCase(nom).map(mapper::toDomain);
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
        return nom != null && jpaRepository.existsByNomIgnoreCase(nom);
    }

    @Override
    public boolean estUtilise(Long id) {
        return id != null && partenaireJpaRepository.existsByTypeId(id);
    }
}
