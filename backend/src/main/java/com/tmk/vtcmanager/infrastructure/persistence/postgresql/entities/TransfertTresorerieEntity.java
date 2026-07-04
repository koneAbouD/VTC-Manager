package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;

@Entity
@Table(name = TransfertTresorerieEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TransfertTresorerieEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "transferts_tresorerie";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "compte_source_id", nullable = false)
    private Long compteSourceId;

    @Column(name = "compte_destination_id", nullable = false)
    private Long compteDestinationId;

    @Column(nullable = false, precision = 19, scale = 2)
    private BigDecimal montant;

    @Column(name = "date_transfert", nullable = false)
    private LocalDate dateTransfert;

    @Column(columnDefinition = "TEXT")
    private String commentaire;
}
