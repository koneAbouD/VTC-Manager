package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.penalite.EncaissementPenalite;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementPenaliteRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.EncaissementPenaliteEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.EncaissementPenaliteJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.LignePenaliteJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.OperationFinanciereJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.LignePenalitePersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class EncaissementPenaliteRepositoryAdapter implements EncaissementPenaliteRepository {

    private final EncaissementPenaliteJpaRepository jpaRepository;
    private final LignePenaliteJpaRepository lignePenaliteJpaRepository;
    private final OperationFinanciereJpaRepository operationFinanciereJpaRepository;
    private final LignePenalitePersistenceMapper mapper;

    /**
     * Un encaissement déjà enregistré est <b>relu puis muté</b>, jamais
     * reconstruit : sans son identifiant, JPA insérerait un second
     * encaissement au lieu de corriger le premier — et l'annulation, au lieu
     * de retirer le versement de la ligne, l'y compterait deux fois.
     */
    @Override
    @Transactional
    public EncaissementPenalite save(EncaissementPenalite encaissement) {
        EncaissementPenaliteEntity entity = encaissement.getId() != null
                ? jpaRepository.findById(encaissement.getId())
                        .orElseThrow(() -> ResourceNotFoundException.of(
                                "Encaissement de pénalité", encaissement.getId()))
                : new EncaissementPenaliteEntity();

        if (encaissement.getLignePenaliteId() != null) {
            entity.setLignePenalite(
                    lignePenaliteJpaRepository.getReferenceById(encaissement.getLignePenaliteId()));
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

        return mapper.toEncaissementDomain(jpaRepository.save(entity));
    }

    @Override
    public Optional<EncaissementPenalite> findById(Long id) {
        return jpaRepository.findById(id).map(mapper::toEncaissementDomain);
    }

    @Override
    public List<EncaissementPenalite> findByLignePenaliteId(Long lignePenaliteId) {
        return jpaRepository.findByLignePenaliteId(lignePenaliteId)
                .stream().map(mapper::toEncaissementDomain).toList();
    }

    @Override
    public Optional<EncaissementPenalite> findByOperationFinanciereId(Long operationFinanciereId) {
        return jpaRepository.findByOperationFinanciereId(operationFinanciereId)
                .map(mapper::toEncaissementDomain);
    }

    @Override
    @Transactional
    public void deleteById(Long id) {
        jpaRepository.deleteById(id);
    }
}
