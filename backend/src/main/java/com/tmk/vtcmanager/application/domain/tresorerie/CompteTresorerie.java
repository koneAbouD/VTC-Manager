package com.tmk.vtcmanager.application.domain.tresorerie;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CompteTresorerie {

    private Long id;
    private String code;
    private String libelle;
    private TypeCompteTresorerie type;
    /** Opérateur mobile money (ORANGE_MONEY, WAVE, MTN…) ; null pour caisse/banque. */
    private String operateur;
    /**
     * Solde constaté à la mise en service du compte (comptage réel) : le
     * solde courant = soldeInitial + somme des opérations non annulées.
     */
    private BigDecimal soldeInitial;
    private boolean parDefaut;
    private boolean actif;
}
