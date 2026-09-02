package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.payment.Paiement;
import com.tmk.vtcmanager.application.domain.payment.TypeCiblePaiement;

import java.util.List;
import java.util.Optional;

public interface PaiementRepository {

    Paiement save(Paiement paiement);

    Optional<Paiement> findByReference(String reference);

    Optional<Paiement> findByGatewayReference(String gatewayReference);

    /**
     * Vrai si un paiement non terminal vise encore cette créance. Son webhook
     * créera un versement au nom du chauffeur qui l'a lancé : la ligne ne doit
     * pas changer de débiteur entre-temps.
     */
    boolean existeEnCours(TypeCiblePaiement typeCible, Long cibleId);

    List<Paiement> findByChauffeurId(Long chauffeurId);
}
