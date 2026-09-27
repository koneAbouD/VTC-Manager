package com.tmk.vtcmanager.application.usecases.contravention;

import com.tmk.vtcmanager.application.domain.contravention.Contravention;
import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import com.tmk.vtcmanager.application.ports.persistence.ContraventionRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.services.CompteTresorerieResolver;
import com.tmk.vtcmanager.application.services.SequenceReferenceService;
import com.tmk.vtcmanager.application.services.CaisseClotureeGuard;
import com.tmk.vtcmanager.application.services.EncaissementFuturGuard;
import com.tmk.vtcmanager.application.services.PeriodeClotureeGuard;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;

@RequiredArgsConstructor
public class PayContraventionUseCase {

    /**
     * Catégorie HORS_RESULTAT (compte de tiers) : le remboursement d'une
     * amende par le chauffeur mouvemente la trésorerie mais n'est pas un
     * produit d'exploitation.
     */
    private static final String CODE_CATEGORIE = "CONTRAVENTION_REMBOURSEMENT";

    private final ContraventionRepository contraventionRepository;
    private final OperationFinanciereRepository operationFinanciereRepository;
    private final CategorieOperationRepository categorieOperationRepository;
    private final CompteTresorerieResolver compteTresorerieResolver;
    private final SequenceReferenceService sequenceReferenceService;
    private final CaisseClotureeGuard caisseClotureeGuard;
    private final PeriodeClotureeGuard periodeClotureeGuard;
    private final EncaissementFuturGuard encaissementFuturGuard;

    @Transactional
    public Contravention execute(Long id, BigDecimal montant, ModePaiement modePaiement) {
        return execute(id, montant, modePaiement, null, null, null);
    }

    /**
     * Encaisse ce que le chauffeur verse sur une contravention : avant
     * reversement, l'argent est détenu pour l'État ; après, il rembourse
     * l'avance que l'entreprise a faite à sa place.
     *
     * @param date        jour où l'argent a été reçu, aujourd'hui si null
     * @param reference   n° de transaction Mobile Money, facultatif
     * @param commentaire facultatif, remplace le libellé par défaut
     */
    @Transactional
    public Contravention execute(Long id, BigDecimal montant, ModePaiement modePaiement,
                                 LocalDate date, String reference, String commentaire) {
        Contravention contravention = contraventionRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Contravention", id));
        if (contravention.estAnnulee() || contravention.getAnnuleLe() != null) {
            throw new IllegalStateException("Contravention annulée : plus rien n'y est dû.");
        }
        if (montant == null || montant.signum() <= 0) {
            throw new IllegalArgumentException("Le montant encaissé doit être positif.");
        }
        BigDecimal reste = contravention.resteDu();
        if (montant.compareTo(reste) > 0) {
            throw new IllegalArgumentException(
                    "Le montant dépasse le reste dû sur la contravention (" + reste.toPlainString() + ").");
        }

        LocalDate jour = date != null ? date : LocalDate.now();
        ModePaiement mode = modePaiement != null ? modePaiement : ModePaiement.ESPECES;
        // Mêmes verrous que tout encaissement : ni avenir, ni période close,
        // ni caisse déjà comptée ce jour-là.
        encaissementFuturGuard.verifier(jour);
        periodeClotureeGuard.verifier(jour);
        Long compteId = compteTresorerieResolver.resoudre(null, mode);
        caisseClotureeGuard.verifier(compteId, jour);

        contravention.enregistrerPaiement(montant, jour);
        Contravention saved = contraventionRepository.save(contravention);

        creerOperation(saved, montant, mode, compteId, jour, reference, commentaire);
        return saved;
    }

    private void creerOperation(Contravention contravention, BigDecimal montant, ModePaiement modePaiement,
                                Long compteId, LocalDate jour, String reference, String commentaire) {
        CategorieOperation categorie = categorieOperationRepository.findByCode(CODE_CATEGORIE).orElse(null);
        String libelle = commentaire != null && !commentaire.isBlank()
                ? commentaire
                : "Remboursement contravention " + (contravention.getTypeInfraction() != null
                        ? contravention.getTypeInfraction() : "#" + contravention.getId());
        if (reference != null && !reference.isBlank()) {
            libelle = libelle + " (réf. " + reference.trim() + ")";
        }

        OperationFinanciere operation = OperationFinanciere.builder()
                .typeOperation(TypeOperation.REVENU)
                .categorie(categorie)
                .chauffeur(contravention.getChauffeur())
                .vehicule(contravention.getVehicule())
                .montant(montant)
                .modePaiement(modePaiement)
                .compteTresorerieId(compteId)
                .dateOperation(jour)
                .dateReference(contravention.getDateInfraction())
                .commentaire(libelle)
                .reference(sequenceReferenceService.suivante(
                        SequenceReferenceService.Journal.CONTRAVENTION, jour))
                .statut(StatutOperation.ENCAISSE)
                // Trace du règlement : à l'annulation de l'écriture, elle seule
                // permet de rendre la contravention à son état antérieur.
                .contraventionId(contravention.getId())
                .build();

        operationFinanciereRepository.save(operation);
    }

}
