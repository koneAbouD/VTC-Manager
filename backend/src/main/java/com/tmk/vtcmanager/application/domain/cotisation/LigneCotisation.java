package com.tmk.vtcmanager.application.domain.cotisation;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class LigneCotisation {

    private Long id;
    private Long vehiculeId;
    private String vehiculeImmatriculation;
    private Long chauffeurId;
    private LocalDate dateCotisation;
    private String nomCotisation;
    private BigDecimal montantDu;
    private BigDecimal montantEncaisse;
    private StatutLigneCotisation statut;
    @Builder.Default
    private List<EncaissementCotisation> encaissements = new ArrayList<>();

    public void recalculerStatutEtMontant() {
        BigDecimal total = encaissements.stream()
                .map(EncaissementCotisation::getMontant)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        this.montantEncaisse = total;

        int cmp = total.compareTo(montantDu);
        if (cmp >= 0) {
            this.statut = StatutLigneCotisation.ENCAISSE;
        } else if (total.compareTo(BigDecimal.ZERO) > 0) {
            this.statut = StatutLigneCotisation.PARTIELLEMENT_ENCAISSE;
        } else {
            this.statut = StatutLigneCotisation.EN_ATTENTE;
        }
    }

    public boolean estActive() {
        return statut == StatutLigneCotisation.EN_ATTENTE
                || statut == StatutLigneCotisation.PARTIELLEMENT_ENCAISSE;
    }

    public BigDecimal montantRestant() {
        BigDecimal encaisse = montantEncaisse != null ? montantEncaisse : BigDecimal.ZERO;
        return montantDu.subtract(encaisse).max(BigDecimal.ZERO);
    }

    public static String normaliserNom(String nom) {
        return nom == null ? null : nom.trim().toLowerCase();
    }
}
