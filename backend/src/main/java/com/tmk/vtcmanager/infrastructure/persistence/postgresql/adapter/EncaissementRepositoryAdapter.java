package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.recette.Encaissement;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.EncaissementEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.LigneRecetteEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.OperationFinanciereEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.EncaissementJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.LigneRecetteJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.OperationFinanciereJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.EncaissementPersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class EncaissementRepositoryAdapter implements EncaissementRepository {

    private final EncaissementJpaRepository jpaRepository;
    private final LigneRecetteJpaRepository ligneRecetteJpaRepository;
    private final OperationFinanciereJpaRepository operationFinanciereJpaRepository;
    private final EncaissementPersistenceMapper mapper;

    /**
     * Un encaissement déjà enregistré est <b>relu puis muté</b>, jamais
     * reconstruit : sans son identifiant, JPA insérerait un second
     * encaissement au lieu de corriger le premier — et l'annulation, au lieu
     * de retirer le versement de la ligne, l'y compterait deux fois.
     */
    @Override
    @Transactional
    public Encaissement save(Encaissement encaissement) {
        EncaissementEntity entity = encaissement.getId() != null
                ? jpaRepository.findById(encaissement.getId())
                        .orElseThrow(() -> ResourceNotFoundException.of(
                                "Encaissement", encaissement.getId()))
                : new EncaissementEntity();

        if (encaissement.getLigneRecetteId() != null) {
            LigneRecetteEntity ligne =
                    ligneRecetteJpaRepository.getReferenceById(encaissement.getLigneRecetteId());
            entity.setLigneRecette(ligne);
        }
        OperationFinanciereEntity operation = encaissement.getOperationFinanciereId() != null
                ? operationFinanciereJpaRepository.getReferenceById(encaissement.getOperationFinanciereId())
                : null;

        entity.setOperationFinanciere(operation);
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
    public Optional<Encaissement> findById(Long id) {
        return jpaRepository.findById(id).map(mapper::toDomain);
    }

    @Override
    public List<Encaissement> findByLigneRecetteId(Long ligneRecetteId) {
        return mapper.toDomainList(jpaRepository.findByLigneRecetteId(ligneRecetteId));
    }

    @Override
    public Optional<Encaissement> findByOperationFinanciereId(Long operationFinanciereId) {
        return jpaRepository.findByOperationFinanciereId(operationFinanciereId).map(mapper::toDomain);
    }

    @Override
    public void deleteById(Long id) {
        jpaRepository.deleteById(id);
    }
}
