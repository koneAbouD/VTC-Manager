package com.tmk.vtcmanager.application.domain.maintenance;

import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.DetailMaintenance;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Maintenance {

    private Long id;
    private String type;
    private LocalDate datePrevue;
    private LocalDate dateEffectuee;
    private Integer dureeHeures;
    private String description;
    private Integer kilometrageAuMoment;
    private Integer kilometrageProchaine;
    private BigDecimal cout;
    private String prestataire;
    private MaintenanceStatus statut;
    /** Statut mémorisé juste avant la complétion, pour une réouverture fidèle. */
    private MaintenanceStatus statutAvantCompletion;
    private Vehicule vehicule;
    private CategorieOperation categorieType;
    private DetailMaintenance detailMaintenance;

    public void initializeDefaults() {
        if (this.statut == null) this.statut = MaintenanceStatus.PLANIFIEE;
    }

    public void terminer(BigDecimal coutEffectif, LocalDate dateEffectuee) {
        // Mémorise le statut d'origine (PLANIFIEE / EN_COURS) pour pouvoir le
        // restaurer si l'opération de dépense générée est annulée.
        this.statutAvantCompletion = this.statut;
        this.statut = MaintenanceStatus.TERMINEE;
        this.dateEffectuee = dateEffectuee != null ? dateEffectuee : LocalDate.now();
        if (coutEffectif != null) {
            this.cout = coutEffectif;
        }
    }

    public void annuler() {
        this.statut = MaintenanceStatus.ANNULEE;
    }

    /**
     * Rouvre une maintenance terminée (retour à l'état antérieur à la
     * complétion) : restaure le statut d'origine mémorisé (PLANIFIEE / EN_COURS,
     * défaut EN_COURS) et efface la date d'exécution et le coût enregistrés lors
     * de la complétion.
     */
    public void reouvrir() {
        this.statut = this.statutAvantCompletion != null
                ? this.statutAvantCompletion
                : MaintenanceStatus.EN_COURS;
        this.statutAvantCompletion = null;
        this.dateEffectuee = null;
        this.cout = null;
    }

    public boolean isPlanifiee() {
        return this.statut == MaintenanceStatus.PLANIFIEE;
    }
}
