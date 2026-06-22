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
    private Vehicule vehicule;
    private CategorieOperation categorieType;
    private DetailMaintenance detailMaintenance;

    public void initializeDefaults() {
        if (this.statut == null) this.statut = MaintenanceStatus.PLANIFIEE;
    }

    public void terminer(BigDecimal coutEffectif, LocalDate dateEffectuee) {
        this.statut = MaintenanceStatus.TERMINEE;
        this.dateEffectuee = dateEffectuee != null ? dateEffectuee : LocalDate.now();
        if (coutEffectif != null) {
            this.cout = coutEffectif;
        }
    }

    public void annuler() {
        this.statut = MaintenanceStatus.ANNULEE;
    }

    public boolean isPlanifiee() {
        return this.statut == MaintenanceStatus.PLANIFIEE;
    }
}
