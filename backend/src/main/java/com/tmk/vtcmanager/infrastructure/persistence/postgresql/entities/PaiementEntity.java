package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import com.tmk.vtcmanager.application.domain.payment.CanalPaiement;
import com.tmk.vtcmanager.application.domain.payment.StatutPaiement;
import com.tmk.vtcmanager.application.domain.payment.TypeCiblePaiement;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "paiements")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PaiementEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 40)
    private String reference;

    @Enumerated(EnumType.STRING)
    @Column(name = "type_cible", nullable = false, length = 20)
    private TypeCiblePaiement typeCible;

    @Column(name = "cible_id", nullable = false)
    private Long cibleId;

    @Column(name = "chauffeur_id", nullable = false)
    private Long chauffeurId;

    @Column(name = "vehicule_id")
    private Long vehiculeId;

    @Column(nullable = false)
    private BigDecimal montant;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private CanalPaiement canal;

    @Column(nullable = false, length = 30)
    private String telephone;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private StatutPaiement statut;

    @Column(name = "gateway_reference", length = 100)
    private String gatewayReference;

    @Column(name = "payment_url")
    private String paymentUrl;

    @Column(name = "encaissement_id")
    private Long encaissementId;

    @Column(name = "message_erreur")
    private String messageErreur;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @PrePersist
    void prePersist() {
        if (createdAt == null) createdAt = LocalDateTime.now();
        if (updatedAt == null) updatedAt = LocalDateTime.now();
    }
}
