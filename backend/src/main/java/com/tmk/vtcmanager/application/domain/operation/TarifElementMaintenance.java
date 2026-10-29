package com.tmk.vtcmanager.application.domain.operation;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * Un élément du catalogue pour un seul modèle de véhicule : son prix, son image
 * et s'il est proposé pour ce modèle.
 *
 * <p>Le même élément peut se payer différemment d'un modèle à l'autre — un pneu
 * de S-Presso n'est pas celui d'une Dzire. Le prix pré-remplit la ligne à la
 * saisie d'une maintenance ; c'est le montant de la ligne qui fait foi.</p>
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TarifElementMaintenance {
    private Long id;
    private Long elementId;
    private Long modeleId;
    private String modeleNom;
    private Long marqueId;
    private String marqueNom;

    /** Facultatif : la main d'œuvre, par exemple, se chiffre à chaque fois. */
    private BigDecimal prix;

    /** Nom d'objet de l'image dans le stockage (facultatif). */
    private String image;

    /** Faux : l'élément n'est plus proposé pour ce modèle, sans être supprimé. */
    private boolean actif;

    public void modifier(BigDecimal prix, String image, boolean actif) {
        if (prix != null && prix.signum() < 0) {
            throw new IllegalArgumentException("Le prix ne peut pas être négatif.");
        }
        this.prix = prix;
        this.image = image;
        this.actif = actif;
    }
}
