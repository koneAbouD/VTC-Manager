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
 * @param resteDu ce qui reste dû sur les créances couvertes, chacune comptée
 *                une fois ; nul dès qu'une créance l'ignore
 */
public record RecuPaiement(
        String entreprise,
        String chauffeurNom,
        String chauffeurTelephone,
        List<String> vehicules,
        List<ModePaiement> modesPaiement,
        List<LigneRecuPaiement> lignes,
        BigDecimal resteDu,
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
