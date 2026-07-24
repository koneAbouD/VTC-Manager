package com.tmk.vtcmanager.application.domain.vehicule;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Balise GPS installée sur un véhicule. Référentiel paramétrable (module
 * Paramètres) : chaque balise porte son identifiant et, éventuellement, le
 * numéro de téléphone de sa carte SIM. Un véhicule référence une balise.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Balise {

    private Long id;
    private String identifiant;
    private String numeroTelephone;
    private boolean actif;

    public static Balise create(String identifiant, String numeroTelephone) {
        return Balise.builder()
                .identifiant(identifiant)
                .numeroTelephone(numeroTelephone)
                .actif(true)
                .build();
    }

    public void update(String identifiant, String numeroTelephone) {
        this.identifiant = identifiant;
        this.numeroTelephone = numeroTelephone;
    }

    public void changerActivation(boolean actif) {
        this.actif = actif;
    }
}
