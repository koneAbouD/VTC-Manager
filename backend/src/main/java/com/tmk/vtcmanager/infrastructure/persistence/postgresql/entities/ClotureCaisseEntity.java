package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;

@Entity
@Table(name = ClotureCaisseEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ClotureCaisseEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "clotures_caisse";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "compte_id", nullable = false)
    private Long compteId;

    @Column(name = "date_cloture", nullable = false)
    private LocalDate dateCloture;

    @Column(name = "solde_theorique", nullable = false, precision = 19, scale = 2)
    private BigDecimal soldeTheorique;

    @Column(name = "solde_compte", nullable = false, precision = 19, scale = 2)
    private BigDecimal soldeCompte;

    @Column(nullable = false, precision = 19, scale = 2)
    private BigDecimal ecart;

    @Column(name = "motif_ecart", columnDefinition = "TEXT")
    private String motifEcart;

    @Column(name = "operation_id")
    private Long operationId;
}
