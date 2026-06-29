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
    /** Statut manuel verrouillant (INACTIF, SUSPENDU). Prioritaire sur le calcul (EN_CONGE/ACTIF). */
    private ChauffeurStatus statutManuel;
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
    }

    public void unassignVehicule() {
        this.vehicule = null;
    }

    /**
     * Indique si le chauffeur porte un statut manuel verrouillant
     * (INACTIF/SUSPENDU) qui doit primer sur le statut calculé.
     */
    public boolean estVerrouille() {
        return statutManuel != null;
    }

    /**
     * Applique le statut résultant des signaux métier, en respectant un
     * éventuel statut manuel verrouillant.
     *
     * @param enConge une indisponibilité couvre la date du jour
     */
    public void appliquerStatutCalcule(boolean enConge) {
        this.statut = estVerrouille()
                ? statutManuel
                : ChauffeurStatusPolicy.compute(enConge);
    }

    /**
     * Applique un statut demandé manuellement (saisie). Les statuts décidés par
     * un humain (INACTIF/SUSPENDU) posent un verrou ; les statuts calculables
     * (ACTIF/EN_CONGE) lèvent le verrou et laissent le recalcul reprendre la main.
     */
    public void appliquerStatutManuel(ChauffeurStatus demande) {
        this.statutManuel = (demande == ChauffeurStatus.INACTIF || demande == ChauffeurStatus.SUSPENDU)
                ? demande
                : null;
        this.statut = demande;
    }
}
