package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import com.tmk.vtcmanager.application.domain.tresorerie.TypeCompteTresorerie;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;

@Entity
@Table(name = CompteTresorerieEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CompteTresorerieEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "comptes_tresorerie";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 50)
    private String code;

    @Column(nullable = false, length = 100)
    private String libelle;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private TypeCompteTresorerie type;

    @Column(length = 30)
    private String operateur;

    @Column(name = "solde_initial", nullable = false, precision = 19, scale = 2)
    private BigDecimal soldeInitial;

    @Column(name = "par_defaut", nullable = false)
    private boolean parDefaut;

    @Column(nullable = false)
    private boolean actif;
}
