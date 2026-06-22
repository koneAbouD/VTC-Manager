package com.tmk.vtcmanager.application.domain.vehicule;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TypeVehicule {

    private Long id;
    private String nom;
    private String description;

    public static TypeVehicule create(String nom, String description) {
        return TypeVehicule.builder()
                .nom(nom)
                .description(description)
                .build();
    }

    public void update(String nom, String description) {
        this.nom = nom;
        this.description = description;
    }
}
