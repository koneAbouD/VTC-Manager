package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.partenaire.FacturePartenaire;
import com.tmk.vtcmanager.application.domain.partenaire.Partenaire;
import com.tmk.vtcmanager.application.domain.partenaire.StatutFacturePartenaire;
import com.tmk.vtcmanager.application.ports.persistence.FacturePartenaireRepository;
import com.tmk.vtcmanager.application.usecases.partenaire.EnregistrerFactureUseCase;
import lombok.RequiredArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

/**
 * Reporte sur les dettes ce qui vient d'être corrigé sur l'intervention.
 *
 * <p>Corriger un coût ou déplacer une ligne d'un prestataire à l'autre doit se
 * voir immédiatement dans l'échéancier : une dette qui resterait au montant
 * d'avant ferait payer au garage ce qu'on ne lui doit plus.
 *
 * <p>Les dettes existantes sont ajustées plutôt que refaites — elles gardent
 * leur référence comptable, leur échéance et leurs règlements. Seul un
 * partenaire qui disparaît de la répartition voit sa dette annulée, et jamais
 * si de l'argent a déjà changé de main : dans ce cas il faut d'abord extourner
 * le règlement, ce que cette classe refuse d'improviser.
 */
@RequiredArgsConstructor
public class SynchronisationDetteMaintenanceService {

    private final FacturePartenaireRepository factureRepository;
    private final EnregistrerFactureUseCase enregistrerFactureUseCase;
    private final RepartitionDetteMaintenanceService repartitionService;

    /**
     * Aligne les dettes de l'intervention sur son état actuel. Sans dette
     * ouverte, il n'y a rien à aligner : une intervention réglée comptant garde
     * son écriture de caisse, qui ne dépend pas d'ici.
     */
    public void synchroniser(Maintenance maintenance) {
        if (maintenance == null || maintenance.getId() == null) return;

        List<FacturePartenaire> dettes = factureRepository.findByMaintenanceId(maintenance.getId())
                .stream()
                .filter(f -> f.getStatut() != StatutFacturePartenaire.ANNULEE)
                .toList();
        if (dettes.isEmpty()) return;

        Map<Long, BigDecimal> cible = repartitionService.repartir(maintenance);

        // Une répartition vide voudrait dire que l'intervention ne doit plus
        // rien à personne. Devant des dettes bien réelles, c'est un signe
        // d'incohérence, pas une instruction : on s'arrête plutôt que d'effacer
        // le passif en silence.
        if (cible.isEmpty()) {
            throw new IllegalStateException(
                    "Cette intervention porte " + dettes.size() + " dette(s) mais plus aucun "
                            + "montant à répartir : renseignez son coût ou ses éléments. "
                            + "Pour éteindre ces dettes, annulez-les depuis l'échéancier.");
        }
        LocalDate echeance = dettes.stream()
                .map(FacturePartenaire::getDateEcheance)
                .filter(java.util.Objects::nonNull)
                .findFirst()
                .orElse(maintenance.getDateEffectuee());

        // 1. Les dettes qui subsistent : on ajuste leur montant.
        for (FacturePartenaire dette : dettes) {
            Long partenaireId = dette.getPartenaire() != null ? dette.getPartenaire().getId() : null;
            BigDecimal montantCible = cible.remove(partenaireId);

            if (montantCible == null) {
                annuler(dette, maintenance);
                continue;
            }
            if (montantCible.compareTo(dette.getMontant()) == 0) continue;

            BigDecimal dejaPaye = dette.getMontantPaye() != null
                    ? dette.getMontantPaye() : BigDecimal.ZERO;
            if (montantCible.compareTo(dejaPaye) < 0) {
                throw new IllegalStateException(
                        "La dette de « " + nom(dette) + " » a déjà été réglée à hauteur de "
                                + dejaPaye.toPlainString() + " : elle ne peut pas descendre à "
                                + montantCible.toPlainString()
                                + ". Extournez d'abord le règlement.");
            }
            dette.setMontant(montantCible);
            dette.setDateFacture(maintenance.getDateEffectuee() != null
                    ? maintenance.getDateEffectuee() : dette.getDateFacture());
            dette.recalculerStatut();
            factureRepository.save(dette);
        }

        // 2. Ce qui reste dans la cible concerne des partenaires nouveaux.
        cible.forEach((partenaireId, montant) -> enregistrerFactureUseCase.executer(
                FacturePartenaire.builder()
                        .partenaire(Partenaire.builder().id(partenaireId).build())
                        .categorie(maintenance.getCategorieType())
                        .vehicule(maintenance.getVehicule())
                        .dateFacture(maintenance.getDateEffectuee())
                        .dateEcheance(echeance)
                        .montant(montant)
                        .maintenanceId(maintenance.getId())
                        .description(description(maintenance))
                        .build()));
    }

    /** Un partenaire retiré de la répartition ne doit plus rien : sa dette s'éteint. */
    private void annuler(FacturePartenaire dette, Maintenance maintenance) {
        BigDecimal dejaPaye = dette.getMontantPaye() != null
                ? dette.getMontantPaye() : BigDecimal.ZERO;
        if (dejaPaye.signum() > 0) {
            throw new IllegalStateException(
                    "La dette de « " + nom(dette) + " » a déjà été réglée en partie : "
                            + "extournez le règlement avant de retirer ce partenaire "
                            + "de l'intervention.");
        }
        dette.setStatut(StatutFacturePartenaire.ANNULEE);
        dette.setMotifAnnulation("Intervention modifiée : ce partenaire n'y figure plus.");
        dette.setAnnuleLe(LocalDateTime.now());
        dette.setMontantPaye(BigDecimal.ZERO);
        factureRepository.save(dette);
    }

    private String nom(FacturePartenaire dette) {
        return dette.getPartenaire() != null && dette.getPartenaire().getNom() != null
                ? dette.getPartenaire().getNom()
                : "partenaire #" + (dette.getPartenaire() != null
                        ? dette.getPartenaire().getId() : "?");
    }

    private String description(Maintenance maintenance) {
        // Sans partenaire, le libellé s'arrête au type (voir CompleteMaintenanceUseCase).
        String prestataire = maintenance.getPartenaire() == null ? null : maintenance.getPartenaire().getNom();
        return "Maintenance %s".formatted(
                maintenance.getType() != null ? maintenance.getType() : "AUTRE")
                + (prestataire == null || prestataire.isBlank() ? "" : " - " + prestataire);
    }
}
