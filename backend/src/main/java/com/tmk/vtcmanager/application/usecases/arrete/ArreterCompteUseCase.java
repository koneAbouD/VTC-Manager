package com.tmk.vtcmanager.application.usecases.arrete;

import com.tmk.vtcmanager.application.domain.arrete.ArreteCompte;
import com.tmk.vtcmanager.application.domain.arrete.LigneArrete;
import com.tmk.vtcmanager.application.domain.arrete.PerimetreArrete;
import com.tmk.vtcmanager.application.domain.arrete.ReglementArrete;
import com.tmk.vtcmanager.application.domain.arrete.SensArrete;
import com.tmk.vtcmanager.application.domain.arrete.StatutArrete;
import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.finance.LigneCreance;
import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.application.domain.penalite.EncaissementPenalite;
import com.tmk.vtcmanager.application.domain.recette.Encaissement;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.ports.persistence.ArreteCompteRepository;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import com.tmk.vtcmanager.application.ports.persistence.ContraventionRepository;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementPenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.services.CompteTresorerieResolver;
import com.tmk.vtcmanager.application.services.PeriodeClotureeGuard;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;

/**
 * Exécute un arrêté de compte : fige le décompte, compense les créances par
 * antériorité via des encaissements <b>cash-neutres</b> (opération sans compte de
 * trésorerie — le cash est déjà entré via la cotisation), décaisse le net positif
 * (« prime », HORS_RESULTAT) et passe les cotisations en RESTITUEE.
 *
 * <p>Le versement se résout toujours par bénéficiaire chauffeur : un arrêté par
 * véhicule multi-chauffeur produit plusieurs règlements.</p>
 */
@RequiredArgsConstructor
public class ArreterCompteUseCase {

    private static final String CAT_RESTITUTION = "RESTITUTION_COTISATIONS";
    private static final String CAT_RECETTE = "ENCAISSEMENT_RECETTES";
    private static final String CAT_PENALITE = "ENCAISSEMENT_PENALITES";
    private static final String CAT_CONTRAVENTION = "CONTRAVENTION_REMBOURSEMENT";
    private static final DateTimeFormatter ANNEE = DateTimeFormatter.ofPattern("yyyy");

    private final CalculerCompteCourantUseCase calculerCompteCourantUseCase;
    private final ArreteCompteRepository arreteCompteRepository;
    private final LigneCotisationRepository ligneCotisationRepository;
    private final LigneRecetteRepository ligneRecetteRepository;
    private final EncaissementRepository encaissementRepository;
    private final LignePenaliteRepository lignePenaliteRepository;
    private final EncaissementPenaliteRepository encaissementPenaliteRepository;
    private final ContraventionRepository contraventionRepository;
    private final OperationFinanciereRepository operationFinanciereRepository;
    private final CategorieOperationRepository categorieOperationRepository;
    private final CompteTresorerieResolver compteTresorerieResolver;
    private final PeriodeClotureeGuard periodeClotureeGuard;

    @Transactional
    public ArreteCompte executer(PerimetreArrete perimetre, Long perimetreId,
                                 LocalDate periodeDebut, LocalDate periodeFin,
                                 LocalDate dateArrete, ModePaiement modePaiement,
                                 Long compteTresorerieId) {
        if (periodeFin.isBefore(periodeDebut)) {
            throw new IllegalArgumentException("La fin de période ne peut précéder son début.");
        }
        LocalDate effetArrete = dateArrete != null ? dateArrete : LocalDate.now();
        periodeClotureeGuard.verifier(effetArrete);

        List<DecompteBeneficiaire> decomptes =
                calculerCompteCourantUseCase.calculer(perimetre, perimetreId, periodeDebut, periodeFin);
        if (decomptes.isEmpty()) {
            throw new IllegalArgumentException("Aucune cotisation ni créance à arrêter sur cette période.");
        }

        String reference = genererReference("ARR");

        ArreteCompte entete = arreteCompteRepository.enregistrerEntete(ArreteCompte.builder()
                .perimetre(perimetre)
                .perimetreId(perimetreId)
                .periodeDebut(periodeDebut)
                .periodeFin(periodeFin)
                .dateArrete(effetArrete)
                .reference(reference)
                .statut(StatutArrete.VALIDE)
                .build());
        Long arreteId = entete.getId();

        List<LigneArrete> lignes = new ArrayList<>();
        List<ReglementArrete> reglements = new ArrayList<>();

        for (DecompteBeneficiaire d : decomptes) {
            // Snapshot du fonds (cotisations, au crédit) + passage en RESTITUEE.
            for (LigneCotisation cot : d.getCotisations()) {
                lignes.add(LigneArrete.builder()
                        .arreteId(arreteId)
                        .document(TypeDocumentCreance.COTISATION)
                        .documentId(cot.getId())
                        .chauffeurId(cot.getChauffeurId())
                        .vehiculeId(cot.getVehiculeId())
                        .montant(cot.getMontantEncaisse())
                        .sens(SensArrete.CREDIT)
                        .build());
                ligneCotisationRepository.marquerRestituee(cot.getId(), arreteId);
            }

            // Compensation des créances (au débit), par antériorité, cash-neutre.
            for (DecompteBeneficiaire.Allocation alloc : d.getAllocations()) {
                LigneCreance creance = alloc.getCreance();
                Long operationId = compenser(creance, alloc.getMontant(), effetArrete, reference);
                lignes.add(LigneArrete.builder()
                        .arreteId(arreteId)
                        .document(creance.getDocument())
                        .documentId(creance.getDocumentId())
                        .chauffeurId(d.getChauffeurId())
                        .vehiculeId(creance.getVehiculeId())
                        .montant(alloc.getMontant())
                        .sens(SensArrete.DEBIT)
                        .operationId(operationId)
                        .build());
            }

            // Décaissement du net positif (« prime »).
            Long operationDecaissementId = null;
            if (d.getNet().signum() > 0) {
                operationDecaissementId = decaisserNet(d, perimetre, perimetreId, effetArrete,
                        modePaiement, compteTresorerieId, reference).getId();
            }

            reglements.add(ReglementArrete.builder()
                    .arreteId(arreteId)
                    .chauffeurId(d.getChauffeurId())
                    .chauffeurNom(d.getChauffeurNom())
                    .totalCotisations(d.getFond())
                    .totalCreancesCompensees(d.getTotalCompense())
                    .montantNet(d.getNet())
                    .reliquatReporte(d.getReliquat())
                    .modePaiement(d.getNet().signum() > 0
                            ? (modePaiement != null ? modePaiement : ModePaiement.ESPECES) : null)
                    .compteTresorerieId(operationDecaissementId != null
                            ? compteTresorerieResolver.resoudre(compteTresorerieId,
                                    modePaiement != null ? modePaiement : ModePaiement.ESPECES) : null)
                    .operationDecaissementId(operationDecaissementId)
                    .build());
        }

        arreteCompteRepository.enregistrerLignes(lignes);
        arreteCompteRepository.enregistrerReglements(reglements);

        return arreteCompteRepository.findById(arreteId).orElse(entete);
    }

    /** Éteint une créance sans mouvementer la trésorerie (compte null) ; renvoie l'id de l'opération de compensation. */
    private Long compenser(LigneCreance creance, BigDecimal montant, LocalDate date, String refArrete) {
        switch (creance.getDocument()) {
            case RECETTE -> {
                OperationFinanciere op = creerOperationCompensation(
                        CAT_RECETTE, creance, montant, date, refArrete);
                encaissementRepository.save(Encaissement.builder()
                        .ligneRecetteId(creance.getDocumentId())
                        .operationFinanciereId(op.getId())
                        .montant(montant)
                        .modeEncaissement(ModePaiement.ESPECES)
                        .dateEncaissement(date)
                        .reference(op.getReference())
                        .commentaire("Compensation cotisation " + refArrete)
                        .build());
                ligneRecetteRepository.recalculerDepuisEncaissements(creance.getDocumentId());
                return op.getId();
            }
            case PENALITE -> {
                OperationFinanciere op = creerOperationCompensation(
                        CAT_PENALITE, creance, montant, date, refArrete);
                encaissementPenaliteRepository.save(EncaissementPenalite.builder()
                        .lignePenaliteId(creance.getDocumentId())
                        .operationFinanciereId(op.getId())
                        .montant(montant)
                        .modeEncaissement(ModePaiement.ESPECES)
                        .dateEncaissement(date)
                        .reference(op.getReference())
                        .commentaire("Compensation cotisation " + refArrete)
                        .build());
                lignePenaliteRepository.recalculerDepuisEncaissements(creance.getDocumentId());
                return op.getId();
            }
            case CONTRAVENTION -> {
                var contravention = contraventionRepository.findById(creance.getDocumentId())
                        .orElseThrow(() -> new IllegalStateException(
                                "Contravention introuvable : " + creance.getDocumentId()));
                contravention.enregistrerPaiement(montant);
                contraventionRepository.save(contravention);
                return creerOperationCompensation(CAT_CONTRAVENTION, creance, montant, date, refArrete).getId();
            }
            case COTISATION -> { /* jamais compensée : le fonds ne se compense pas lui-même */ }
        }
        return null;
    }

    private OperationFinanciere creerOperationCompensation(String codeCategorie, LigneCreance creance,
                                                          BigDecimal montant, LocalDate date, String refArrete) {
        CategorieOperation categorie = categorieOperationRepository.findByCode(codeCategorie).orElse(null);
        OperationFinanciere op = OperationFinanciere.builder()
                .typeOperation(TypeOperation.REVENU)
                .categorie(categorie)
                .chauffeur(chauffeurRef(creance.getChauffeurId()))
                .vehicule(vehiculeRef(creance.getVehiculeId()))
                .montant(montant)
                .modePaiement(ModePaiement.ESPECES)
                .compteTresorerieId(null) // cash-neutre : le cash est déjà entré via la cotisation
                .dateOperation(date)
                .dateReference(creance.getDateReference())
                .commentaire("Compensation cotisation " + refArrete)
                .reference(genererReference("COMP"))
                .statut(StatutOperation.ENCAISSE)
                .build();
        return operationFinanciereRepository.save(op);
    }

    private OperationFinanciere decaisserNet(DecompteBeneficiaire d, PerimetreArrete perimetre, Long perimetreId,
                                             LocalDate date, ModePaiement modePaiement, Long compteTresorerieId,
                                             String refArrete) {
        ModePaiement mode = modePaiement != null ? modePaiement : ModePaiement.ESPECES;
        CategorieOperation categorie = categorieOperationRepository.findByCode(CAT_RESTITUTION).orElse(null);
        OperationFinanciere op = OperationFinanciere.builder()
                .typeOperation(TypeOperation.DEPENSE)
                .categorie(categorie)
                .chauffeur(chauffeurRef(d.getChauffeurId()))
                .vehicule(perimetre == PerimetreArrete.VEHICULE ? vehiculeRef(perimetreId) : null)
                .montant(d.getNet())
                .modePaiement(mode)
                .compteTresorerieId(compteTresorerieResolver.resoudre(compteTresorerieId, mode))
                .dateOperation(date)
                .dateReference(date)
                .commentaire("Restitution cotisations " + refArrete + " - " + d.getChauffeurNom())
                .reference(genererReference("RES"))
                .statut(StatutOperation.PAYE)
                .build();
        return operationFinanciereRepository.save(op);
    }

    private Vehicule vehiculeRef(Long id) {
        if (id == null) return null;
        Vehicule v = new Vehicule();
        v.setId(id);
        return v;
    }

    private Chauffeur chauffeurRef(Long id) {
        if (id == null) return null;
        Chauffeur c = new Chauffeur();
        c.setId(id);
        return c;
    }

    /** Références uniques (VARCHAR(30)) : préfixe + année + horodatage nanos (base 36, monotone). */
    private String genererReference(String prefixe) {
        return prefixe + "-" + LocalDate.now().format(ANNEE) + "-" + Long.toString(System.nanoTime(), 36);
    }
}
