package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.ColumnDefault;

@Entity
@Table(name = PartenaireEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PartenaireEntity extends AbstractEcritureAuditEntity {

    public static final String TABLE_NAME = "partenaires";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 150)
    private String nom;

    @ManyToOne(fetch = FetchType.EAGER, optional = false)
    @JoinColumn(name = "type_partenaire_id", nullable = false)
    private TypePartenaireEntity type;

    @Column(length = 30)
    private String telephone;

    @Column(length = 150)
    private String email;

    @Column(length = 255)
    private String adresse;

    @Column(name = "numero_compte_contribuable", length = 50)
    private String numeroCompteContribuable;

    @Column(columnDefinition = "TEXT")
    private String commentaire;

    @Builder.Default
    @Column(nullable = false)
    @ColumnDefault("true")
    private Boolean actif = true;
}
