package com.tmk.vtcmanager.application.domain.operation;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CatalogueElementMaintenance {

    private Long id;
    private String libelle;
    private boolean actif;

    public void update(String libelle) {
        this.libelle = libelle;
    }

    public void changerActivation(boolean actif) {
        this.actif = actif;
    }
}
