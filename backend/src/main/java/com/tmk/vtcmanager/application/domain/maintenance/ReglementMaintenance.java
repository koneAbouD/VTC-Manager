package com.tmk.vtcmanager.application.domain.maintenance;

import com.tmk.vtcmanager.application.domain.operation.ModePaiement;

import java.time.LocalDate;

/**
 * Comment l'intervention est réglée au moment où on la termine.
 *
 * <p>Deux issues seulement, et elles ne produisent pas la même écriture : payée
 * comptant, l'intervention sort l'argent de la caisse le jour même ; laissée à
 * payer, elle ne bouge aucune trésorerie mais fait naître une dette envers le
 * ou les partenaires, soldée plus tard par son règlement.
 *
 * @param aCredit      vrai si l'intervention reste due
 * @param echeance     quand la dette est exigible ; à défaut, due à réception
 * @param modePaiement moyen employé — n'a de sens qu'au comptant
 */
public record ReglementMaintenance(boolean aCredit, LocalDate echeance, ModePaiement modePaiement) {

    public static ReglementMaintenance comptant(ModePaiement modePaiement) {
        return new ReglementMaintenance(false, null,
                modePaiement != null ? modePaiement : ModePaiement.ESPECES);
    }

    public static ReglementMaintenance aCredit(LocalDate echeance) {
        return new ReglementMaintenance(true, echeance, null);
    }

    public ModePaiement modePaiementOuDefaut() {
        return modePaiement != null ? modePaiement : ModePaiement.ESPECES;
    }
}
