package com.tmk.vtcmanager.application.domain.arrete;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

/**
 * Arrêté de compte : compensation des dettes et créances réciproques d'un
 * périmètre (chauffeur ou véhicule) sur une période libre, figée à une date.
 * Fait comptable immuable — annulable seulement avec motif.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ArreteCompte {

    private Long id;
    private PerimetreArrete perimetre;
    private Long perimetreId;
    /** Libellé du périmètre (nom chauffeur ou immatriculation), transient. */
    private String perimetreLibelle;
    private LocalDate periodeDebut;
    private LocalDate periodeFin;
    private LocalDate dateArrete;
    private String reference;
    private StatutArrete statut;
    private String motifAnnulation;

    @Builder.Default
    private List<LigneArrete> lignes = new ArrayList<>();
    @Builder.Default
    private List<ReglementArrete> reglements = new ArrayList<>();

    /** Total restitué (somme des nets positifs des règlements). */
    public BigDecimal totalRestitue() {
        return reglements.stream()
                .map(ReglementArrete::getMontantNet)
                .filter(m -> m != null && m.signum() > 0)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }
}
