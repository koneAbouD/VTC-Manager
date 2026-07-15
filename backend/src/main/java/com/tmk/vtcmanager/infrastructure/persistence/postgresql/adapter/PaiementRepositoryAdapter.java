package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.payment.Paiement;
import com.tmk.vtcmanager.application.ports.persistence.PaiementRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.PaiementEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.PaiementJpaRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class PaiementRepositoryAdapter implements PaiementRepository {

    private final PaiementJpaRepository jpaRepository;

    @Override
    @Transactional
    public Paiement save(Paiement paiement) {
        return toDomain(jpaRepository.save(toEntity(paiement)));
    }

    @Override
    @Transactional(readOnly = true)
    public Optional<Paiement> findByReference(String reference) {
        return jpaRepository.findByReference(reference).map(this::toDomain);
    }

    @Override
    @Transactional(readOnly = true)
    public Optional<Paiement> findByGatewayReference(String gatewayReference) {
        return jpaRepository.findByGatewayReference(gatewayReference).map(this::toDomain);
    }

    @Override
    @Transactional(readOnly = true)
    public List<Paiement> findByChauffeurId(Long chauffeurId) {
        return jpaRepository.findByChauffeurIdOrderByCreatedAtDesc(chauffeurId)
                .stream().map(this::toDomain).toList();
    }

    private PaiementEntity toEntity(Paiement d) {
        return PaiementEntity.builder()
                .id(d.getId())
                .reference(d.getReference())
                .typeCible(d.getTypeCible())
                .cibleId(d.getCibleId())
                .chauffeurId(d.getChauffeurId())
                .vehiculeId(d.getVehiculeId())
                .montant(d.getMontant())
                .canal(d.getCanal())
                .telephone(d.getTelephone())
                .statut(d.getStatut())
                .gatewayReference(d.getGatewayReference())
                .paymentUrl(d.getPaymentUrl())
                .encaissementId(d.getEncaissementId())
                .messageErreur(d.getMessageErreur())
                .createdAt(d.getCreatedAt())
                .updatedAt(d.getUpdatedAt())
                .build();
    }

    private Paiement toDomain(PaiementEntity e) {
        return Paiement.builder()
                .id(e.getId())
                .reference(e.getReference())
                .typeCible(e.getTypeCible())
                .cibleId(e.getCibleId())
                .chauffeurId(e.getChauffeurId())
                .vehiculeId(e.getVehiculeId())
                .montant(e.getMontant())
                .canal(e.getCanal())
                .telephone(e.getTelephone())
                .statut(e.getStatut())
                .gatewayReference(e.getGatewayReference())
                .paymentUrl(e.getPaymentUrl())
                .encaissementId(e.getEncaissementId())
                .messageErreur(e.getMessageErreur())
                .createdAt(e.getCreatedAt())
                .updatedAt(e.getUpdatedAt())
                .build();
    }
}
