package com.tmk.vtcmanager.application.domain.operation;

import com.tmk.vtcmanager.application.domain.partenaire.Partenaire;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.math.RoundingMode;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ElementMaintenance {

    private Long id;
    private CatalogueElementMaintenance catalogueElement; // null si entrée libre
    private String libelle;                               // null si catalogue utilisé

    /**
     * Nombre d'exemplaires posés. Null sur les lignes d'avant la quantité, et
     * sur celles qui n'en parlent pas : {@link #getQuantiteEffective()} les
     * traite comme un exemplaire.
     */
    private Integer quantite;

    /**
     * TOTAL de la ligne — quantité × prix unitaire, pas le prix d'un
     * exemplaire. Tout ce qui somme les éléments (coût de l'intervention,
     * répartition des dettes) lit ce champ.
     */
    private BigDecimal montant;

    /**
     * Qui fournit cette ligne. Null = le partenaire de l'intervention : un seul
     * prestataire fait tout, cas de loin le plus fréquent. Renseigné quand le
     * chantier en mêle plusieurs — le garage répare, un autre vend les pièces.
     */
    private Partenaire partenaire;

    /** Retourne le libellé effectif quelle que soit l'origine. */
    public String getEffectiveLibelle() {
        return catalogueElement != null ? catalogueElement.getLibelle() : libelle;
    }

    /** Quantité posée, ramenée à un exemplaire quand elle n'est pas dite. */
    public int getQuantiteEffective() {
        return quantite != null && quantite > 0 ? quantite : 1;
    }

    /**
     * Prix d'un exemplaire, retrouvé par division : le stocker en plus du
     * total ferait deux vérités à tenir d'accord. Deux décimales, comme le
     * montant lui-même.
     */
    public BigDecimal getPrixUnitaire() {
        if (montant == null) return null;
        return montant.divide(BigDecimal.valueOf(getQuantiteEffective()), 2, RoundingMode.HALF_UP);
    }
}
