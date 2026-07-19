package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.contravention.Contravention;
import com.tmk.vtcmanager.application.domain.contravention.ContraventionStatus;
import com.tmk.vtcmanager.application.ports.persistence.ContraventionRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ContraventionEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.ContraventionJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.ContraventionPersistenceMapper;
import jakarta.persistence.criteria.Predicate;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class ContraventionRepositoryAdapter implements ContraventionRepository {

    private final ContraventionJpaRepository jpaRepository;
    private final ContraventionPersistenceMapper mapper;

    /**
     * Tri d'affichage : date de l'infraction la plus récente d'abord, puis date
     * de création en second (départage les infractions de même date, ex. import
     * en lot où tous les createdAt sont quasi identiques).
     */
    private static final Sort SORT_RECENT = Sort.by(
            Sort.Order.desc("dateInfraction"),
            Sort.Order.desc("createdAt"));

    @Override
    public Contravention save(Contravention contravention) {
        return mapper.toDomain(jpaRepository.save(mapper.toEntity(contravention)));
    }

    @Override
    public Optional<Contravention> findById(Long id) {
        return jpaRepository.findById(id).map(mapper::toDomain);
    }

    @Override
    public List<Contravention> findAll() {
        return mapper.toDomainList(jpaRepository.findAll(SORT_RECENT));
    }

    @Override
    public PageResult<Contravention> findPage(Long chauffeurId, Long vehiculeId, int page, int size) {
        Specification<ContraventionEntity> spec = (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();
            if (chauffeurId != null) {
                predicates.add(cb.equal(root.get("chauffeur").get("id"), chauffeurId));
            }
            if (vehiculeId != null) {
                predicates.add(cb.equal(root.get("vehicule").get("id"), vehiculeId));
            }
            return cb.and(predicates.toArray(new Predicate[0]));
        };
        Page<Contravention> result = jpaRepository
                .findAll(spec, PageRequest.of(page, size, SORT_RECENT))
                .map(mapper::toDomain);
        return new PageResult<>(
                result.getContent(), result.getNumber(), result.getSize(), result.getTotalElements());
    }

    @Override
    public List<Contravention> findByChauffeurId(Long chauffeurId) {
        return mapper.toDomainList(jpaRepository.findByChauffeurId(chauffeurId, SORT_RECENT));
    }

    @Override
    public List<Contravention> findByVehiculeId(Long vehiculeId) {
        return mapper.toDomainList(jpaRepository.findByVehiculeId(vehiculeId, SORT_RECENT));
    }

    @Override
    public List<Contravention> findByStatut(ContraventionStatus statut) {
        return mapper.toDomainList(jpaRepository.findByStatut(statut));
    }

    @Override
    public boolean existsByNumero(String numeroContravention) {
        return numeroContravention != null
                && jpaRepository.existsByNumeroContravention(numeroContravention);
    }

    @Override
    public Optional<Contravention> findByNumero(String numeroContravention) {
        if (numeroContravention == null) {
            return Optional.empty();
        }
        return jpaRepository.findByNumeroContravention(numeroContravention).map(mapper::toDomain);
    }

    @Override
    public void deleteById(Long id) {
        jpaRepository.deleteById(id);
    }
}
