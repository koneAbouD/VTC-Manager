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
    private String numeroTelephoneBalise;
    private String identifiantBalise;
    private String couleur;
    private Integer kilometrage;
    private VehiculeStatus statut;
    /** Statut manuel verrouillant (IMMOBILISE pour panne/accident, HORS_PARC). Prioritaire sur le calcul. */
    private VehiculeStatus statutManuel;
    private TypeVehicule type;
    private TypeActivite activite;
    private GroupeVehicule groupe;
    private ConditionTravail conditionTravail;
    private LocalDate dateAchat;
    /** Prix d'acquisition : base de l'amortissement et du bilan de gestion. */
    private java.math.BigDecimal prixAchat;
    /** Durée d'amortissement linéaire en mois (60 par défaut). */
    @Builder.Default
    private int dureeAmortissementMois = 60;
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

    /**
     * Indique si le véhicule porte un statut manuel verrouillant
     * (IMMOBILISE/HORS_PARC) qui doit primer sur le statut calculé.
     */
    public boolean estVerrouille() {
        return statutManuel != null;
    }

    /**
     * Applique le statut résultant des signaux métier, en respectant un
     * éventuel statut manuel verrouillant.
     *
     * @param indisponibiliteActive immobilisation planifiée (indisponibilité véhicule) en cours
     * @param immobilisationActive  immobilisation pénalité en cours sur le véhicule
     * @param maintenanceEnCours    au moins une maintenance EN_COURS
     * @param chauffeurAffecte      un chauffeur est affecté au véhicule
     */
    public void appliquerStatutCalcule(boolean indisponibiliteActive,
                                       boolean immobilisationActive,
                                       boolean maintenanceEnCours,
                                       boolean chauffeurAffecte) {
        this.statut = estVerrouille()
                ? statutManuel
                : VehiculeStatusPolicy.compute(indisponibiliteActive, immobilisationActive,
                        maintenanceEnCours, chauffeurAffecte);
    }

    /**
     * Applique un statut demandé manuellement (saisie). Les statuts décidés par
     * un humain (IMMOBILISE pour panne/accident, HORS_PARC) posent un verrou ;
     * les statuts calculables lèvent le verrou et laissent le recalcul reprendre
     * la main.
     */
    public void appliquerStatutManuel(VehiculeStatus demande) {
        this.statutManuel = (demande == VehiculeStatus.IMMOBILISE || demande == VehiculeStatus.HORS_PARC)
                ? demande
                : null;
        this.statut = demande;
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
