package com.tmk.vtcmanager.application.usecases.operationFinanciere;

import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.ports.security.AuteurCourant;
import com.tmk.vtcmanager.application.services.AnnulationEncaissementService;
import com.tmk.vtcmanager.application.services.AnnulationMaintenanceService;
import com.tmk.vtcmanager.application.services.PeriodeClotureeGuard;
import com.tmk.vtcmanager.application.services.SequenceReferenceService;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * Annulation d'une écriture par contre-passation.
 *
 * <p>L'écriture d'origine n'est ni supprimée ni neutralisée : elle a existé,
 * elle reste au journal avec son montant et sa date. On lui oppose une
 * <em>extourne</em> — même type, même catégorie, même compte, montant opposé —
 * datée du jour de l'annulation. Le couple s'annule dans les soldes comme dans
 * la cascade du compte de résultat, sans qu'aucune requête d'agrégat n'ait à
 * connaître la notion d'extourne.
 */
@RequiredArgsConstructor
public class AnnulerOperationFinanciereUseCase {

    private final OperationFinanciereRepository operationRepository;
    private final AnnulationEncaissementService annulationEncaissementService;
    private final AnnulationMaintenanceService annulationMaintenanceService;
    private final PeriodeClotureeGuard periodeClotureeGuard;
    private final SequenceReferenceService sequenceReferenceService;
    private final AuteurCourant auteurCourant;

    @Transactional
    public OperationFinanciere execute(Long id, String motif) {
        if (motif == null || motif.isBlank()) {
            throw new IllegalArgumentException(
                    "Le motif d'annulation est obligatoire : il justifie la contre-passation.");
        }

        OperationFinanciere origine = operationRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Opération", id));

        if (origine.estUneExtourne()) {
            throw new IllegalStateException(
                    "Une extourne ne s'annule pas : elle corrige déjà une écriture.");
        }
        if (origine.estExtournee()) {
            throw new IllegalStateException("L'opération est déjà extournée.");
        }

        // L'écriture d'origine ne doit pas appartenir à une période close…
        periodeClotureeGuard.verifier(origine.getDateOperation());
        // …et la contre-passation, datée du jour, doit tomber dans une période
        // ouverte : sinon la correction n'apparaîtrait dans aucun état.
        LocalDate dateExtourne = LocalDate.now();
        periodeClotureeGuard.verifier(dateExtourne);

        String auteur = auteurCourant.nom();
        origine.setMotifAnnulation(motif);
        origine.setAnnulePar(auteur);
        origine.setAnnuleLe(LocalDateTime.now());
        OperationFinanciere origineSauvee = operationRepository.save(origine);

        operationRepository.save(construireExtourne(origineSauvee, dateExtourne, motif));

        // L'encaissement sous-jacent (recette / cotisation / pénalité) est marqué
        // annulé — jamais supprimé — et la ligne recalculée sans lui.
        annulationEncaissementService.annulerEncaissementLie(origineSauvee, auteur, motif);

        // Une dépense issue d'une maintenance rouvre la maintenance.
        annulationMaintenanceService.reouvrirMaintenanceLiee(origineSauvee);

        return origineSauvee;
    }

    private OperationFinanciere construireExtourne(OperationFinanciere origine,
                                                   LocalDate date, String motif) {
        return OperationFinanciere.builder()
                .reference(sequenceReferenceService.suivante(
                        SequenceReferenceService.Journal.EXTOURNE, date))
                .typeOperation(origine.getTypeOperation())
                .categorie(origine.getCategorie())
                .sousCategorie(origine.getSousCategorie())
                .chauffeur(origine.getChauffeur())
                .vehicule(origine.getVehicule())
                // Montant opposé : c'est lui qui neutralise l'origine partout où
                // les montants sont sommés, sans toucher à une seule requête.
                .montant(origine.getMontant().negate())
                .modePaiement(origine.getModePaiement())
                .compteTresorerieId(origine.getCompteTresorerieId())
                .dateOperation(date)
                .dateReference(origine.getDateReference())
                .statut(origine.getStatut())
                .extourneDeId(origine.getId())
                .commentaire("Extourne de " + origine.getReference() + " — " + motif)
                .build();
    }
}
