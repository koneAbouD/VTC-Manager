package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.indisponibilite.Indisponibilite;
import com.tmk.vtcmanager.application.domain.indisponibilite.IndisponibiliteStatut;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.IndisponibiliteEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.IndisponibiliteJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.IndisponibilitePersistenceMapper;
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
public class IndisponibiliteRepositoryAdapter implements IndisponibiliteRepository {

    private final IndisponibiliteJpaRepository jpaRepository;
    private final IndisponibilitePersistenceMapper mapper;

    @Override
    public Indisponibilite save(Indisponibilite indisponibilite) {
        return mapper.toDomain(jpaRepository.save(mapper.toEntity(indisponibilite)));
    }

    @Override
    public Optional<Indisponibilite> findById(Long id) {
        return jpaRepository.findById(id).map(mapper::toDomain);
    }

    @Override
    public List<Indisponibilite> findAll() {
        return mapper.toDomainList(jpaRepository.findAll(Sort.by(Sort.Direction.DESC, "dateDebut")));
    }

    @Override
    public PageResult<Indisponibilite> findPage(Long chauffeurId, int page, int size) {
        Pageable pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "dateDebut"));
        Page<IndisponibiliteEntity> result = (chauffeurId != null)
                ? jpaRepository.findByChauffeurId(chauffeurId, pageable)
                : jpaRepository.findAll(pageable);
        return new PageResult<>(
                mapper.toDomainList(result.getContent()),
                result.getNumber(), result.getSize(), result.getTotalElements());
    }

    @Override
    public List<Indisponibilite> findByChauffeurId(Long chauffeurId) {
        return mapper.toDomainList(jpaRepository.findByChauffeurIdOrderByDateDebutDesc(chauffeurId));
    }

    @Override
    public List<Indisponibilite> findByStatut(IndisponibiliteStatut statut) {
        return mapper.toDomainList(jpaRepository.findByStatut(statut));
    }

    @Override
    public boolean isEnCongeAt(Long chauffeurId, LocalDate date) {
        return jpaRepository.isEnCongeAt(chauffeurId, date,
                List.of(IndisponibiliteStatut.PLANIFIEE, IndisponibiliteStatut.EN_COURS));
    }

    @Override
    public boolean isRemplacantActifAt(Long chauffeurId, LocalDate date) {
        return jpaRepository.isRemplacantActifAt(chauffeurId, date,
                List.of(IndisponibiliteStatut.PLANIFIEE, IndisponibiliteStatut.EN_COURS));
    }

    @Override
    public void deleteById(Long id) {
        jpaRepository.deleteById(id);
    }
}
