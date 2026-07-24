package com.tmk.vtcmanager.application.domain.parametre;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Réglage global de l'application, stocké en clé-valeur. Le libellé et la
 * description sont figés par le seed (ils décrivent le rôle du paramètre) ;
 * seule la valeur est modifiable par l'administrateur.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ParametreGeneral {
    private String cle;
    private String valeur;
    private String libelle;
    private String description;
}
