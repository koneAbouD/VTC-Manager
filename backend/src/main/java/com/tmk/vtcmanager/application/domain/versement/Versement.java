package com.tmk.vtcmanager.application.domain.versement;

import com.tmk.vtcmanager.application.domain.operation.ModePaiement;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * La pièce de caisse : un billet, et les écritures qu'il a produites.
 *
 * <p>Ce n'est pas une écriture de plus. Le journal garde une écriture par
 * créance — la recette au résultat, la cotisation en compte de tiers — et le
 * versement ne fait que les lire ensemble.
 */
public record Versement(
        UUID versementId,
        LocalDate dateEncaissement,
        ModePaiement modePaiement,
        Long chauffeurId,
        String chauffeurNom,
        String chauffeurTelephone,
        Long vehiculeId,
        String vehiculeImmatriculation,
        List<ImputationVersement> imputations
) {

    /** Ce que le versement vaut encore : une imputation extournée n'y compte plus. */
    public BigDecimal total() {
        return imputations.stream()
                .filter(i -> !i.annulee())
                .map(ImputationVersement::montant)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }
}
