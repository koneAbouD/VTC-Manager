package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.application.domain.payment.StatutPaiement;
import com.tmk.vtcmanager.application.domain.payment.TypeCiblePaiement;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.PaiementEntity;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface PaiementJpaRepository extends JpaRepository<PaiementEntity, Long> {

    Optional<PaiementEntity> findByReference(String reference);

    Optional<PaiementEntity> findByGatewayReference(String gatewayReference);

    List<PaiementEntity> findByChauffeurIdOrderByCreatedAtDesc(Long chauffeurId);

    /**
     * Un paiement encore en vol sur cette créance : son webhook créera un
     * versement au nom du chauffeur qui l'a lancé.
     */
    boolean existsByTypeCibleAndCibleIdAndStatutIn(TypeCiblePaiement typeCible, Long cibleId,
                                                   Collection<StatutPaiement> statuts);
}
