package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.vehicule.Vidange;
import com.tmk.vtcmanager.application.ports.persistence.VidangeRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.VidangeJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.VidangePersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Repository
@RequiredArgsConstructor
public class VidangeRepositoryAdapter implements VidangeRepository {

    private final VidangeJpaRepository jpaRepository;
    private final VidangePersistenceMapper mapper;

    @Override
    public Vidange save(Vidange vidange) {
        return mapper.toDomain(jpaRepository.save(mapper.toEntity(vidange)));
    }

    @Override
    public List<Vidange> findByVehiculeId(Long vehiculeId) {
        return mapper.toDomainList(
                jpaRepository.findByVehiculeIdOrderByDateVidangeDescIdDesc(vehiculeId));
    }

    @Override
    public Optional<Vidange> findDerniereByVehiculeId(Long vehiculeId) {
        return jpaRepository.findFirstByVehiculeIdOrderByDateVidangeDescIdDesc(vehiculeId)
                .map(mapper::toDomain);
    }

    @Override
    public List<Vidange> findDernieresAvecProchaineEntre(LocalDate debut, LocalDate fin) {
        return mapper.toDomainList(
                jpaRepository.findDernieresAvecProchaineEntre(debut, fin));
    }

    @Override
    public List<Vidange> findDernieresParVehicule() {
        return mapper.toDomainList(jpaRepository.findDernieresParVehicule());
    }
}
