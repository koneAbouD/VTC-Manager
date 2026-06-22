package com.tmk.vtcmanager.application.domain.vehicule;

import com.tmk.vtcmanager.application.domain.conditionTravail.ConditionTravail;
import com.tmk.vtcmanager.application.domain.groupe.GroupeVehicule;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Vehicule {

    private Long id;
    private String immatriculation;
    private Marque marque;
    private Modele modele;
    private String numeroChassis;
    private String numeroTelephoneVehicule;
    private String numeroTelephoneBalise;
    private String identifiantBalise;
    private String couleur;
    private Integer kilometrage;
    private VehiculeStatus statut;
    private TypeVehicule type;
    private TypeActivite activite;
    private GroupeVehicule groupe;
    private ConditionTravail conditionTravail;
    private LocalDate dateAchat;
    private LocalDate dateProchaineMaintenance;
    private LocalDate dateMiseEnCirculation;
    private LocalDate dateEntreeFlotte;

    @Builder.Default
    private List<VehiculePhoto> photos = new ArrayList<>();

    /**
     * Règles métier sur les dates :
     *  - la date de mise en circulation ne peut pas être postérieure
     *    à la date d'entrée dans la flotte ;
     *  - la date d'entrée dans la flotte ne peut pas être postérieure
     *    à la date du jour.
     */
    public void validateDates() {
        if (dateMiseEnCirculation != null
                && dateEntreeFlotte != null
                && dateMiseEnCirculation.isAfter(dateEntreeFlotte)) {
            throw new IllegalArgumentException(
                    "La date de mise en circulation ne peut pas être postérieure à la date d'entrée dans la flotte.");
        }
        if (dateEntreeFlotte != null
                && dateEntreeFlotte.isAfter(LocalDate.now())) {
            throw new IllegalArgumentException(
                    "La date d'entrée dans la flotte ne peut pas être postérieure à la date du jour.");
        }
    }

    public void activate() {
        this.statut = VehiculeStatus.EN_SERVICE;
    }

    public void release() {
        this.statut = VehiculeStatus.DISPONIBLE;
    }

    public void setToMaintenance() {
        this.statut = VehiculeStatus.EN_MAINTENANCE;
    }

    public void updateKilometrage(Integer newKilometrage) {
        if (newKilometrage != null && (this.kilometrage == null || newKilometrage > this.kilometrage)) {
            this.kilometrage = newKilometrage;
        }
    }

    public void updateProchaineMaintenance(LocalDate date) {
        if (date != null && (this.dateProchaineMaintenance == null || date.isBefore(this.dateProchaineMaintenance))) {
            this.dateProchaineMaintenance = date;
        }
    }

    public Long getMarqueId() {
        return marque != null ? marque.getId() : null;
    }

    public Long getModeleId() {
        return modele != null ? modele.getId() : null;
    }

    public Long getTypeVehiculeId() {
        return type != null ? type.getId() : null;
    }

    public Long getTypeActiviteId() {
        return activite != null ? activite.getId() : null;
    }

    public Long getGroupeId() {
        return groupe != null ? groupe.getId() : null;
    }

    public Long getConditionTravailId() {
        return conditionTravail != null ? conditionTravail.getId() : null;
    }
}
