package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDate;

@Entity
@Table(name = EncaissementEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class EncaissementEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "encaissements";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "ligne_recette_id", nullable = false)
    private LigneRecetteEntity ligneRecette;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "operation_financiere_id")
    private OperationFinanciereEntity operationFinanciere;

    @Column(name = "montant", precision = 19, scale = 2, nullable = false)
    private BigDecimal montant;

    @Enumerated(EnumType.STRING)
    @Column(name = "mode_encaissement", nullable = false, length = 20)
    private ModePaiement modeEncaissement;

    @Column(name = "date_encaissement", nullable = false)
    private LocalDate dateEncaissement;

    @Column(name = "reference", length = 100)
    private String reference;

    @Column(name = "commentaire")
    private String commentaire;
}
