package com.tmk.vtcmanager.application.domain.vehicule;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Marque {

    private Long id;
    private String nom;
    private TypeVehicule type;
    private String paysOrigine;
    private boolean actif;

    public static Marque create(String nom, TypeVehicule type, String paysOrigine) {
        return Marque.builder()
                .nom(nom)
                .type(type)
                .paysOrigine(paysOrigine)
                .actif(true)
                .build();
    }

    public void update(String nom, TypeVehicule type, String paysOrigine) {
        this.nom = nom;
        this.type = type;
        this.paysOrigine = paysOrigine;
    }

    public void changerActivation(boolean actif) {
        this.actif = actif;
    }
}
