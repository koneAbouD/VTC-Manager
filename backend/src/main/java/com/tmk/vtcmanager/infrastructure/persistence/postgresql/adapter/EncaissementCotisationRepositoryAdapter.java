package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.cotisation.EncaissementCotisation;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementCotisationRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.EncaissementCotisationEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.EncaissementCotisationJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.LigneCotisationJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.OperationFinanciereJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.EncaissementCotisationPersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class EncaissementCotisationRepositoryAdapter implements EncaissementCotisationRepository {

    private final EncaissementCotisationJpaRepository jpaRepository;
    private final LigneCotisationJpaRepository ligneCotisationJpaRepository;
    private final OperationFinanciereJpaRepository operationFinanciereJpaRepository;
    private final EncaissementCotisationPersistenceMapper mapper;

    /**
     * Un encaissement déjà enregistré est <b>relu puis muté</b>, jamais
     * reconstruit : sans son identifiant, JPA insérerait un second
     * encaissement au lieu de corriger le premier — et l'annulation, au lieu
     * de retirer le versement de la ligne, l'y compterait deux fois.
     */
    @Override
    @Transactional
    public EncaissementCotisation save(EncaissementCotisation encaissement) {
        EncaissementCotisationEntity entity = encaissement.getId() != null
                ? jpaRepository.findById(encaissement.getId())
                        .orElseThrow(() -> ResourceNotFoundException.of(
                                "Encaissement de cotisation", encaissement.getId()))
                : new EncaissementCotisationEntity();

        if (encaissement.getLigneCotisationId() != null) {
            entity.setLigneCotisation(
                    ligneCotisationJpaRepository.getReferenceById(encaissement.getLigneCotisationId()));
        }
        entity.setOperationFinanciere(encaissement.getOperationFinanciereId() != null
                ? operationFinanciereJpaRepository.getReferenceById(encaissement.getOperationFinanciereId())
                : null);
        entity.setMontant(encaissement.getMontant());
        entity.setModeEncaissement(encaissement.getModeEncaissement());
        entity.setDateEncaissement(encaissement.getDateEncaissement());
        entity.setReference(encaissement.getReference());
        entity.setCommentaire(encaissement.getCommentaire());
        entity.setAnnuleLe(encaissement.getAnnuleLe());
        entity.setAnnulePar(encaissement.getAnnulePar());
        entity.setMotifAnnulation(encaissement.getMotifAnnulation());

        return mapper.toDomain(jpaRepository.save(entity));
    }

    @Override
    public Optional<EncaissementCotisation> findById(Long id) {
        return jpaRepository.findById(id).map(mapper::toDomain);
    }

    @Override
    public List<EncaissementCotisation> findByLigneCotisationId(Long ligneCotisationId) {
        return mapper.toDomainList(jpaRepository.findByLigneCotisationId(ligneCotisationId));
    }

    @Override
    public Optional<EncaissementCotisation> findByOperationFinanciereId(Long operationFinanciereId) {
        return jpaRepository.findByOperationFinanciereId(operationFinanciereId).map(mapper::toDomain);
    }

    @Override
    @Transactional
    public void deleteById(Long id) {
        jpaRepository.deleteById(id);
    }
}
