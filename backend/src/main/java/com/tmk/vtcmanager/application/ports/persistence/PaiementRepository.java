package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.payment.Paiement;

import java.util.List;
import java.util.Optional;

public interface PaiementRepository {

    Paiement save(Paiement paiement);

    Optional<Paiement> findByReference(String reference);

    Optional<Paiement> findByGatewayReference(String gatewayReference);

    List<Paiement> findByChauffeurId(Long chauffeurId);
}
