package com.tmk.vtcmanager.application.domain.recu;

import com.tmk.vtcmanager.application.domain.operation.ModePaiement;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Objects;

/**
 * Le reçu remis au chauffeur : ce qu'il a versé, pour quelles créances, et ce
 * qu'il doit encore sur elles.
 *
 * <p>Un reçu n'a qu'un destinataire. Il peut couvrir un versement — la recette
 * et la cotisation du jour — ou toutes les journées qu'un chauffeur a soldées
 * d'un même geste de caisse.
 *
 * @param resteDu ce qui reste à payer sur la recette et la cotisation des
 *                journées couvertes (pour un reçu de pénalité seule : sur ses
 *                créances) ; nul dès qu'une recette au réel l'ignore
 * @param detteChauffeur le total des créances du chauffeur — recettes,
 *                pénalités et contraventions échues, hors cotisation — tel que
 *                le module Créances le lit ; nul quand le reçu n'a pas de
 *                chauffeur. C'est lui, avec {@code resteDu}, qui dit s'il est
 *                à jour : solder une journée ne solde pas les autres
 * @param chauffeurAuVolant vrai si le chauffeur est en service et au planning
 *                du jour, faux s'il est en service mais au repos aujourd'hui,
 *                nul pour tout autre statut : le message le salue en
 *                conséquence
 */
public record RecuPaiement(
        String entreprise,
        String chauffeurNom,
        String chauffeurTelephone,
        List<String> vehicules,
        List<ModePaiement> modesPaiement,
        List<LigneRecuPaiement> lignes,
        BigDecimal resteDu,
        BigDecimal detteChauffeur,
        Boolean chauffeurAuVolant,
        LocalDateTime emisLe
) {

    public BigDecimal total() {
        return lignes.stream().map(LigneRecuPaiement::montant)
                .filter(Objects::nonNull)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    /** Les jours où l'argent a été reçu, du plus ancien au plus récent. */
    public List<LocalDate> datesPaiement() {
        return lignes.stream().map(LigneRecuPaiement::payeLe)
                .filter(Objects::nonNull).distinct().sorted().toList();
    }
}
