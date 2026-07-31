package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.operation.ElementMaintenance;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Qui doit quoi, sur une intervention laissée à payer.
 *
 * <p>Le garage répare, un autre vend les pièces : ce sont deux créanciers, et
 * la règle qui les départage doit être la même quand la maintenance est
 * terminée et quand elle est modifiée ensuite — sans quoi une simple correction
 * ferait diverger l'échéancier.
 */
public class RepartitionDetteMaintenanceService {

    /**
     * Montant dû à chaque partenaire, dans l'ordre où les lignes apparaissent —
     * l'échéancier reflète ainsi la saisie.
     *
     * <p>Chaque ligne va à son prestataire ; celles qui n'en ont pas au
     * partenaire de l'intervention. Le coût validé fait foi : s'il s'écarte de
     * la somme des lignes (remise consentie, montant arrondi au moment de
     * payer), l'écart est porté par le partenaire principal.
     *
     * @throws IllegalArgumentException si une ligne ne peut être rattachée à
     *         aucun partenaire — une dette sans créancier n'existe pas
     */
    public Map<Long, BigDecimal> repartir(Maintenance maintenance) {
        Long partenairePrincipal = maintenance.getPartenaire() != null
                ? maintenance.getPartenaire().getId() : null;

        List<ElementMaintenance> elements = maintenance.getDetailMaintenance() != null
                && maintenance.getDetailMaintenance().getElements() != null
                        ? maintenance.getDetailMaintenance().getElements()
                        : List.of();

        Map<Long, BigDecimal> parPartenaire = new LinkedHashMap<>();
        BigDecimal totalLignes = BigDecimal.ZERO;

        for (ElementMaintenance element : elements) {
            if (element.getMontant() == null) continue;
            Long partenaireId = element.getPartenaire() != null
                    ? element.getPartenaire().getId() : partenairePrincipal;
            if (partenaireId == null) {
                throw new IllegalArgumentException(
                        "Indiquez à quel partenaire « " + element.getEffectiveLibelle()
                                + " » est dû, ou renseignez le partenaire de l'intervention.");
            }
            parPartenaire.merge(partenaireId, element.getMontant(), BigDecimal::add);
            totalLignes = totalLignes.add(element.getMontant());
        }

        // Sans coût arrêté, l'intervention vaut ses lignes. Prendre zéro
        // reviendrait à dire qu'on ne doit rien, alors que le travail est fait.
        BigDecimal cout = maintenance.getCout() != null && maintenance.getCout().signum() > 0
                ? maintenance.getCout()
                : totalLignes;
        BigDecimal ecart = cout.subtract(totalLignes);
        if (ecart.signum() != 0 || parPartenaire.isEmpty()) {
            if (partenairePrincipal != null) {
                parPartenaire.merge(partenairePrincipal, ecart, BigDecimal::add);
            } else if (!parPartenaire.isEmpty()) {
                // Toutes les lignes ont leur prestataire : il n'existe pas de
                // partenaire principal pour absorber une remise globale, alors
                // elle se répartit sur ceux qui la consentent, au prorata.
                repartirAuProrata(parPartenaire, ecart, totalLignes);
            } else {
                throw new IllegalArgumentException(
                        "Renseignez le partenaire de l'intervention : sans lui, "
                                + "impossible de savoir à qui la dette est due.");
            }
        }
        // Une ligne ramenée à zéro (ou compensée par l'écart) n'est pas une dette.
        parPartenaire.values().removeIf(montant -> montant.signum() <= 0);
        return parPartenaire;
    }

    /**
     * Étale un écart sur les partenaires, chacun au poids de ses lignes. Le
     * dernier absorbe le reliquat d'arrondi : la somme des dettes doit tomber
     * au franc près sur le coût de l'intervention, sinon le passif ne collerait
     * plus à la charge.
     */
    private void repartirAuProrata(Map<Long, BigDecimal> parPartenaire,
                                   BigDecimal ecart, BigDecimal totalLignes) {
        if (totalLignes.signum() == 0) return;

        List<Long> partenaires = List.copyOf(parPartenaire.keySet());
        BigDecimal distribue = BigDecimal.ZERO;

        for (int i = 0; i < partenaires.size(); i++) {
            Long partenaireId = partenaires.get(i);
            BigDecimal part = i == partenaires.size() - 1
                    ? ecart.subtract(distribue)
                    : ecart.multiply(parPartenaire.get(partenaireId))
                            .divide(totalLignes, 2, RoundingMode.HALF_UP);
            distribue = distribue.add(part);
            parPartenaire.merge(partenaireId, part, BigDecimal::add);
        }
    }
}
