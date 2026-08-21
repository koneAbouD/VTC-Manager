package com.tmk.vtcmanager.application.usecases.arrete;

import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.finance.LigneCreance;
import lombok.Getter;

import java.math.BigDecimal;
import java.util.List;

/**
 * Décompte calculé pour UN bénéficiaire chauffeur : son fonds de cotisation de
 * la période face à ses créances ouvertes, l'allocation de compensation (par
 * antériorité), le net à restituer et le reliquat reporté.
 */
@Getter
public class DecompteBeneficiaire {

    private final Long chauffeurId;
    private final String chauffeurNom;
    /** Lignes de cotisation actives de la période (le fonds), à passer RESTITUEE. */
    private final List<LigneCotisation> cotisations;
    private final BigDecimal fond;
    /**
     * Toutes les créances ouvertes retenues, y compris celles que le fonds ne
     * couvre pas. L'écran doit les montrer : ce qui reste dû après l'arrêté
     * fait partie du décompte, au même titre que ce qui est éteint.
     */
    private final List<LigneCreance> creances;
    /** Créance compensée → montant imputé (par antériorité). Sous-ensemble de {@link #creances}. */
    private final List<Allocation> allocations;
    private final BigDecimal totalCompense;
    private final BigDecimal net;
    private final BigDecimal reliquat;

    public DecompteBeneficiaire(Long chauffeurId, String chauffeurNom,
                                List<LigneCotisation> cotisations, BigDecimal fond,
                                List<LigneCreance> creances, List<Allocation> allocations,
                                BigDecimal totalCompense, BigDecimal net, BigDecimal reliquat) {
        this.chauffeurId = chauffeurId;
        this.chauffeurNom = chauffeurNom;
        this.cotisations = cotisations;
        this.fond = fond;
        this.creances = creances;
        this.allocations = allocations;
        this.totalCompense = totalCompense;
        this.net = net;
        this.reliquat = reliquat;
    }

    /** Vrai s'il y a quelque chose à montrer : un fonds, une compensation ou un reste dû. */
    public boolean estNonVide() {
        return fond.signum() > 0 || !allocations.isEmpty() || reliquat.signum() > 0;
    }

    /**
     * Vrai si l'arrêté <b>écrirait</b> quelque chose pour ce bénéficiaire.
     *
     * <p>Un reliquat seul ne suffit pas : constater qu'un chauffeur reste
     * débiteur est une information d'écran, pas un fait comptable. L'enregistrer
     * produirait un arrêté sans aucune ligne, avec un règlement à zéro — du
     * bruit dans l'historique et dans le relevé du chauffeur.
     */
    public boolean aMatiereAArreter() {
        return fond.signum() > 0 || !allocations.isEmpty();
    }

    /** Montant imputé à une créance donnée, zéro si le fonds ne l'a pas atteinte. */
    public BigDecimal montantCompense(LigneCreance creance) {
        return allocations.stream()
                .filter(a -> a.getCreance() == creance)
                .map(Allocation::getMontant)
                .findFirst()
                .orElse(BigDecimal.ZERO);
    }

    /** Créance compensée et montant imputé. */
    @Getter
    public static class Allocation {
        private final LigneCreance creance;
        private final BigDecimal montant;

        public Allocation(LigneCreance creance, BigDecimal montant) {
            this.creance = creance;
            this.montant = montant;
        }
    }
}
