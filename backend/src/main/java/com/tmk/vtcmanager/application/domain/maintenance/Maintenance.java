package com.tmk.vtcmanager.application.domain.maintenance;

import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.DetailMaintenance;
import com.tmk.vtcmanager.application.domain.partenaire.Partenaire;
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
    /**
     * Qui a réalisé l'intervention. C'était un texte libre : deux orthographes
     * du même garage faisaient deux prestataires, et rien ne se regroupait. Le
     * partenaire est désormais choisi dans le répertoire.
     */
    private Partenaire partenaire;
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

    /**
     * Rouvre une maintenance terminée : elle repart PLANIFIEE, sans date
     * d'exécution ni coût.
     *
     * <p>La complétion annulée n'a pas eu lieu — l'intervention est à refaire
     * en entier, elle doit donc réapparaître parmi les maintenances à planifier
     * et non parmi celles qu'on croirait en cours au garage.
     */
    public void reouvrir() {
        this.statut = MaintenanceStatus.PLANIFIEE;
        this.dateEffectuee = null;
        this.cout = null;
    }

    public boolean isPlanifiee() {
        return this.statut == MaintenanceStatus.PLANIFIEE;
    }
}
