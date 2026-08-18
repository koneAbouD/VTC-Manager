package com.tmk.vtcmanager.application.usecases.operationFinanciere;

import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.ports.security.AuteurCourant;
import com.tmk.vtcmanager.application.services.AnnulationContraventionService;
import com.tmk.vtcmanager.application.services.AnnulationEncaissementService;
import com.tmk.vtcmanager.application.services.AnnulationMaintenanceService;
import com.tmk.vtcmanager.application.services.PeriodeClotureeGuard;
import com.tmk.vtcmanager.application.services.SequenceReferenceService;
import com.tmk.vtcmanager.application.services.CaisseClotureeGuard;
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
    private final AnnulationContraventionService annulationContraventionService;
    private final AnnulationMaintenanceService annulationMaintenanceService;
    private final PeriodeClotureeGuard periodeClotureeGuard;
    private final SequenceReferenceService sequenceReferenceService;
    private final AuteurCourant auteurCourant;
    private final CaisseClotureeGuard caisseClotureeGuard;

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
        // Neutralisée par ailleurs — l'annulation d'un arrêté de compte, par
        // exemple, passe ses écritures en ANNULEE sans les extourner. La
        // repasser ici décompterait une seconde fois la créance qu'elle réglait.
        if (origine.getStatut() == StatutOperation.ANNULEE) {
            throw new IllegalStateException("L'opération est déjà annulée.");
        }

        // Seule la contre-passation est soumise au verrou de période : datée du
        // jour, elle doit tomber dans une période ouverte, sinon la correction
        // n'apparaîtrait dans aucun état. L'écriture d'origine, elle, peut
        // appartenir à un mois déjà clos — c'est même le cas normal d'une erreur
        // découverte après coup. Elle n'est pas retouchée : elle reste au journal
        // avec sa date et son montant, les états publiés du mois clos ne bougent
        // pas, et la correction pèse sur le mois où elle est décidée.
        LocalDate dateExtourne = LocalDate.now();
        periodeClotureeGuard.verifier(dateExtourne);
        // …et la caisse qu'elle mouvemente ne doit pas avoir déjà été comptée
        // ce jour-là : sinon le procès-verbal de comptage deviendrait faux.
        caisseClotureeGuard.verifier(origine.getCompteTresorerieId(), dateExtourne);

        String auteur = auteurCourant.nom();
        origine.setMotifAnnulation(motif);
        origine.setAnnulePar(auteur);
        origine.setAnnuleLe(LocalDateTime.now());
        OperationFinanciere origineSauvee = operationRepository.save(origine);

        operationRepository.save(construireExtourne(origineSauvee, dateExtourne, motif));

        // L'encaissement sous-jacent (recette / cotisation / pénalité) est marqué
        // annulé — jamais supprimé — et la ligne recalculée sans lui : elle
        // retrouve son statut EN_ATTENTE ou PARTIELLEMENT_ENCAISSE.
        annulationEncaissementService.annulerEncaissementLie(origineSauvee, auteur, motif);

        // Même principe pour une contravention réglée : le montant versé
        // redescend et la créance redevient due.
        annulationContraventionService.annulerPaiementLie(origineSauvee);

        // Une dépense issue d'une maintenance la rouvre : elle repart PLANIFIEE.
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
