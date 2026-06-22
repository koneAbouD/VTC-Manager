package com.tmk.vtcmanager.application.domain.groupe;

import com.tmk.vtcmanager.application.domain.vehicule.TypeActivite;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GroupeVehicule {

    private Long id;
    private String nom;
    private String description;
    private TypeActivite typeActivite;
    private GroupeStatut statut;
    private GestionnaireGroupe gestionnaire;
    private int nbVehicules;
}