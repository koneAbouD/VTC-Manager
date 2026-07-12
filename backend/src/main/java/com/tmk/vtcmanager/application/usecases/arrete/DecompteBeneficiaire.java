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
    /** Créance compensée → montant imputé (par antériorité). */
    private final List<Allocation> allocations;
    private final BigDecimal totalCompense;
    private final BigDecimal net;
    private final BigDecimal reliquat;

    public DecompteBeneficiaire(Long chauffeurId, String chauffeurNom,
                                List<LigneCotisation> cotisations, BigDecimal fond,
                                List<Allocation> allocations, BigDecimal totalCompense,
                                BigDecimal net, BigDecimal reliquat) {
        this.chauffeurId = chauffeurId;
        this.chauffeurNom = chauffeurNom;
        this.cotisations = cotisations;
        this.fond = fond;
        this.allocations = allocations;
        this.totalCompense = totalCompense;
        this.net = net;
        this.reliquat = reliquat;
    }

    /** Vrai s'il y a matière à un arrêté (un fonds ou des créances). */
    public boolean estNonVide() {
        return fond.signum() > 0 || !allocations.isEmpty() || reliquat.signum() > 0;
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
