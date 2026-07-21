package com.tmk.vtcmanager.application.domain.vehicule;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Modele {

    private Long id;
    private String nom;
    private TypeVehicule type;
    private Marque marque;
    private boolean actif;

    public static Modele create(String nom, TypeVehicule type, Marque marque) {
        return Modele.builder()
                .nom(nom)
                .type(type)
                .marque(marque)
                .actif(true)
                .build();
    }

    public void update(String nom, TypeVehicule type, Marque marque) {
        this.nom = nom;
        this.type = type;
        this.marque = marque;
    }

    public void changerActivation(boolean actif) {
        this.actif = actif;
    }
}
