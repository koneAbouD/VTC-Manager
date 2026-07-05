package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;
import jakarta.persistence.CascadeType;
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
import jakarta.persistence.OneToMany;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = LigneCotisationEntity.TABLE_NAME)
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class LigneCotisationEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "lignes_cotisation";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "vehicule_id", nullable = false)
    private VehiculeEntity vehicule;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "chauffeur_id", nullable = false)
    private ChauffeurEntity chauffeur;

    @Column(name = "date_cotisation", nullable = false)
    private LocalDate dateCotisation;

    @Column(name = "nom_cotisation", nullable = false, length = 100)
    private String nomCotisation;

    @Column(name = "montant_du", precision = 19, scale = 2, nullable = false)
    private BigDecimal montantDu;

    @Column(name = "montant_encaisse", precision = 19, scale = 2, nullable = false)
    private BigDecimal montantEncaisse;

    @Enumerated(EnumType.STRING)
    @Column(name = "statut", nullable = false, length = 30)
    private StatutLigneCotisation statut;

    @Column(name = "motif_annulation", length = 500)
    private String motifAnnulation;

    @OneToMany(mappedBy = "ligneCotisation", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @Builder.Default
    private List<EncaissementCotisationEntity> encaissements = new ArrayList<>();
}
