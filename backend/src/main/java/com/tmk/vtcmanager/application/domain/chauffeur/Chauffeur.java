package com.tmk.vtcmanager.application.domain.chauffeur;

import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.time.Period;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Chauffeur {

    private Long id;
    private String nom;
    private String prenom;
    private Genre genre;
    private TypeChauffeur type;
    private LocalDate dateNaissance;
    private String photoUrl;
    private String photoPresignedUrl;
    private String telephone;
    private String email;
    private String adresse;
    private ChauffeurStatus statut;
    private LocalDate dateEmbauche;
    private Geolocalisation geolocalisation;
    private Vehicule vehicule;

    public Integer getAge() {
        if (dateNaissance == null) return null;
        return Period.between(dateNaissance, LocalDate.now()).getYears();
    }

    public String getFullName() {
        return (prenom == null ? "" : prenom) + " " + (nom == null ? "" : nom);
    }

    public void assignVehicule(Vehicule vehicule) {
        this.vehicule = vehicule;
        if (vehicule != null) {
            vehicule.activate();
        }
    }

    public void unassignVehicule() {
        if (this.vehicule != null) {
            this.vehicule.release();
        }
        this.vehicule = null;
    }
}
