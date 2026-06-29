package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.vehicule.StatutVehicule;
import com.tmk.vtcmanager.application.ports.persistence.StatutVehiculeRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.StatutVehiculeJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.StatutVehiculePersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
@RequiredArgsConstructor
public class StatutVehiculeRepositoryAdapter implements StatutVehiculeRepository {

    private final StatutVehiculeJpaRepository jpaRepository;
    private final StatutVehiculePersistenceMapper mapper;

    @Override
    public List<StatutVehicule> findAll() {
        return jpaRepository.findAll(Sort.by(Sort.Direction.ASC, "ordre")).stream()
                .map(mapper::toDomain)
                .toList();
    }

    @Override
    public Optional<StatutVehicule> findByCode(String code) {
        return jpaRepository.findById(code)
                .map(mapper::toDomain);
    }
}
