package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatutHistorique;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeStatutHistoriqueRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.VehiculeStatutHistoriqueJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.VehiculeStatutHistoriquePersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
@RequiredArgsConstructor
public class VehiculeStatutHistoriqueRepositoryAdapter implements VehiculeStatutHistoriqueRepository {

    private final VehiculeStatutHistoriqueJpaRepository jpaRepository;
    private final VehiculeStatutHistoriquePersistenceMapper mapper;

    @Override
    public VehiculeStatutHistorique save(VehiculeStatutHistorique historique) {
        return mapper.toDomain(jpaRepository.save(mapper.toEntity(historique)));
    }

    @Override
    public Optional<VehiculeStatutHistorique> findEnCoursByVehiculeId(Long vehiculeId) {
        return jpaRepository.findByVehiculeIdAndDateFinIsNull(vehiculeId)
                .map(mapper::toDomain);
    }

    @Override
    public List<VehiculeStatutHistorique> findAllEnCours() {
        return mapper.toDomainList(jpaRepository.findByDateFinIsNull());
    }

    @Override
    public List<VehiculeStatutHistorique> findByVehiculeId(Long vehiculeId) {
        return mapper.toDomainList(jpaRepository.findByVehiculeIdOrderByDateDebutDesc(vehiculeId));
    }
}
