package com.tmk.vtcmanager.application.usecases.partenaire;

import com.tmk.vtcmanager.application.domain.partenaire.FacturePartenaire;
import com.tmk.vtcmanager.application.domain.partenaire.StatutFacturePartenaire;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.FacturePartenaireRepository;
import com.tmk.vtcmanager.application.ports.security.AuteurCourant;
import com.tmk.vtcmanager.application.services.PeriodeClotureeGuard;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * Annulation d'une facture reçue à tort.
 *
 * <p>Réservée aux factures qu'aucun règlement n'a touchées : dès qu'une somme a
 * été payée, l'annulation effacerait une sortie de caisse réelle. Dans ce cas,
 * la voie est d'extourner le règlement d'abord.
 */
@RequiredArgsConstructor
public class AnnulerFactureUseCase {

    private final FacturePartenaireRepository factureRepository;
    private final PeriodeClotureeGuard periodeClotureeGuard;
    private final AuteurCourant auteurCourant;

    @Transactional
    public FacturePartenaire executer(Long factureId, String motif) {
        if (motif == null || motif.isBlank()) {
            throw new IllegalArgumentException("Le motif d'annulation est obligatoire.");
        }
        FacturePartenaire facture = factureRepository.findById(factureId)
                .orElseThrow(() -> ResourceNotFoundException.of("Facture partenaire", factureId));

        if (facture.getStatut() == StatutFacturePartenaire.ANNULEE) {
            throw new IllegalStateException("Cette facture est déjà annulée.");
        }
        if (facture.getMontantPaye() != null && facture.getMontantPaye().signum() > 0) {
            throw new IllegalStateException("Cette facture a déjà été réglée en partie : "
                    + "extournez d'abord le règlement.");
        }
        // La charge portée par la facture appartient à sa période : on ne la
        // retire pas d'un mois déjà publié.
        periodeClotureeGuard.verifier(facture.getDateFacture());

        facture.setStatut(StatutFacturePartenaire.ANNULEE);
        facture.setMotifAnnulation(motif);
        facture.setAnnuleLe(LocalDateTime.now());
        facture.setAnnulePar(auteurCourant.nom());
        facture.setMontantPaye(BigDecimal.ZERO);
        return factureRepository.save(facture);
    }
}
