package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.indisponibilite.IndisponibiliteStatut;
import com.tmk.vtcmanager.application.domain.indisponibiliteVehicule.IndisponibiliteVehicule;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteVehiculeRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.IndisponibiliteVehiculeEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.IndisponibiliteVehiculeJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.IndisponibiliteVehiculePersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class IndisponibiliteVehiculeRepositoryAdapter implements IndisponibiliteVehiculeRepository {

    private final IndisponibiliteVehiculeJpaRepository jpaRepository;
    private final IndisponibiliteVehiculePersistenceMapper mapper;

    @Override
    public IndisponibiliteVehicule save(IndisponibiliteVehicule indisponibilite) {
        return mapper.toDomain(jpaRepository.save(mapper.toEntity(indisponibilite)));
    }

    @Override
    public Optional<IndisponibiliteVehicule> findById(Long id) {
        return jpaRepository.findById(id).map(mapper::toDomain);
    }

    @Override
    public List<IndisponibiliteVehicule> findAll() {
        return mapper.toDomainList(jpaRepository.findAll(Sort.by(Sort.Direction.DESC, "dateDebut")));
    }

    @Override
    public PageResult<IndisponibiliteVehicule> findPage(Long vehiculeId, int page, int size) {
        Pageable pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "dateDebut"));
        Page<IndisponibiliteVehiculeEntity> result = (vehiculeId != null)
                ? jpaRepository.findByVehiculeId(vehiculeId, pageable)
                : jpaRepository.findAll(pageable);
        return new PageResult<>(
                mapper.toDomainList(result.getContent()),
                result.getNumber(), result.getSize(), result.getTotalElements());
    }

    @Override
    public List<IndisponibiliteVehicule> findByVehiculeId(Long vehiculeId) {
        return mapper.toDomainList(jpaRepository.findByVehiculeIdOrderByDateDebutDesc(vehiculeId));
    }

    @Override
    public List<IndisponibiliteVehicule> findByStatut(IndisponibiliteStatut statut) {
        return mapper.toDomainList(jpaRepository.findByStatut(statut));
    }

    @Override
    public boolean isImmobiliseAt(Long vehiculeId, LocalDate date) {
        return jpaRepository.isImmobiliseAt(vehiculeId, date,
                List.of(IndisponibiliteStatut.PLANIFIEE, IndisponibiliteStatut.EN_COURS));
    }

    @Override
    public void deleteById(Long id) {
        jpaRepository.deleteById(id);
    }
}
