package com.tmk.vtcmanager.application.domain.vehicule;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TypeActivite {

    private Long id;
    private String nom;
    private String description;
    private boolean actif;

    public static TypeActivite create(String nom, String description) {
        return TypeActivite.builder()
                .nom(nom)
                .description(description)
                .actif(true)
                .build();
    }

    public void update(String nom, String description) {
        this.nom = nom;
        this.description = description;
    }

    public void changerActivation(boolean actif) {
        this.actif = actif;
    }
}