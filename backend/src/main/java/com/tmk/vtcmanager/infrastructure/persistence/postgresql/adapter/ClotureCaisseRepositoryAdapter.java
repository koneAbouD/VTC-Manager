package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.tresorerie.ClotureCaisse;
import com.tmk.vtcmanager.application.ports.persistence.ClotureCaisseRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ClotureCaisseEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.ClotureCaisseJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.TresoreriePersistenceMappers;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class ClotureCaisseRepositoryAdapter implements ClotureCaisseRepository {

    private final ClotureCaisseJpaRepository jpaRepository;
    private final TresoreriePersistenceMappers mapper;

    @Override
    public ClotureCaisse save(ClotureCaisse cloture) {
        return mapper.toDomain(jpaRepository.save(mapper.toEntity(cloture)));
    }

    @Override
    public boolean existsByCompteIdAndDateCloture(Long compteId, LocalDate date) {
        return jpaRepository.existsByCompteIdAndDateClotureAndAnnuleLeIsNull(compteId, date);
    }

    @Override
    public List<ClotureCaisse> findByCompteIdOrderByDateDesc(Long compteId) {
        return mapper.toClotureCaisseDomainList(
                jpaRepository.findByCompteIdAndAnnuleLeIsNullOrderByDateClotureDesc(compteId));
    }

    @Override
    public List<ClotureCaisse> findHistoriqueByCompteId(Long compteId) {
        return mapper.toClotureCaisseDomainList(
                jpaRepository.findByCompteIdOrderByDateClotureDescIdDesc(compteId));
    }

    @Override
    public Optional<LocalDate> findDerniereDateCloture(Long compteId) {
        return jpaRepository.findFirstByCompteIdAndAnnuleLeIsNullOrderByDateClotureDesc(compteId)
                .map(ClotureCaisseEntity::getDateCloture);
    }

    @Override
    public Optional<LocalDate> findDerniereDateClotureALaDate(Long compteId, LocalDate date) {
        return jpaRepository
                .findFirstByCompteIdAndAnnuleLeIsNullAndDateClotureLessThanEqualOrderByDateClotureDesc(
                        compteId, date)
                .map(ClotureCaisseEntity::getDateCloture);
    }

    @Override
    public Optional<LocalDate> findDerniereDateClotureToutesCaisses() {
        return jpaRepository.findFirstByAnnuleLeIsNullOrderByDateClotureDesc()
                .map(ClotureCaisseEntity::getDateCloture);
    }

    @Override
    public java.util.Map<Long, LocalDate> findDernieresClotureParCompte() {
        return jpaRepository.dernieresClotureParCompte().stream()
                .collect(java.util.stream.Collectors.toMap(
                        ligne -> (Long) ligne[0], ligne -> (LocalDate) ligne[1]));
    }

    @Override
    public List<ClotureCaisse> findEcartsEnAttente() {
        return mapper.toClotureCaisseDomainList(
                jpaRepository.findByImputationStatutAndAnnuleLeIsNullOrderByDateClotureAsc(
                        com.tmk.vtcmanager.application.domain.tresorerie
                                .StatutImputationEcart.EN_ATTENTE));
    }

    @Override
    public Optional<ClotureCaisse> findById(Long id) {
        return jpaRepository.findById(id).map(mapper::toDomain);
    }
}
